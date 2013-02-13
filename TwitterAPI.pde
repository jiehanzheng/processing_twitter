import org.json.*;
import oauthP5.apis.TwitterApi;
import oauthP5.oauth.*;
import java.util.ArrayList;
import java.util.regex.*;


class TwitterAPI {

  /**
   * Request batch size
   *
   * Fetch X tweets at a time.
   */
  int batchSize = 2;

  /**
   * Cache tweets to reduce Twitter API usage
   *
   * Every time <code>getTweet()</code> is called, one tweet JSONObject is taken
   * out from <code>cachedTweets</code>.  When we runs out of cached tweets, 
   * <code>getTweet()</code> will fetch more from Twitter API and store them.
   */
  ArrayList<String> cachedTweets = new ArrayList<String>();

  /**
   * Fetched tweet id ranges
   *
   * Consider this situation, where we fetch two tweets at a time:
   *
   *  ID'S WE FETCHED DURING
   *  1ST GETTWEET() CALL
   *  +--------------------+
   *  | 100000000000000000 |
   *  |  99999999999999999 |
   *  +--------------------+
   *
   * Then, X amount of time passed, we fetch another two, but in reality, this 
   * can be what happened on Twitter:
   *
   *  ID'S IN TWITTER DB
   *  DURING 2ND CALL
   *  +--------------------+
   *  | 100000000000000003 | YES
   *  | 100000000000000002 | YES
   *  | 100000000000000001 | NEVER fetched!
   *  | 100000000000000000 | OLD
   *  |  99999999999999999 | OLD
   *  |         ...        |
   *  +--------------------+
   *
   * As you can see, tweet #100000000000000001 is never going to be able to be
   * fetched.  So, our revised strategy is: keep a record of what we already got
   * and try "unfetched" ranges until we get to <code>batchSize</code>.
   *
   * To not let this ArrayList grow ridiculously long, we will merge continuous
   * ranges.
   */
  ArrayList<TweetIdRange> fetchedIdRanges = new ArrayList<TweetIdRange>();

  /**
   * Twitter stuff
   *
   * It would make sense if Google Docs / FusionTables asked for OAuth
   * authentication, but why do I have to be OAuth-authenticated to search 
   * Twitter...  Why not just use IP-based rate limiting...
   *
   * Do not abuse my keys...  anyone using this combination shares the 
   * 180reqs/15mins quota.
   */
  OAuthService service;
  final String CONSUMER_KEY = "BMJAwlAKgDEw1MrgZqfHqQ"; // use your own app's key...
  final String CONSUMER_SECRET = "GM59Nr4c296Tqog74lNGBzai1za5CgrvlwRc3nnY2Cg";
  final String ACCESS_TOKEN = "34873459-B3GQy8y6d3iRN5UV24ys3ErL62j5tAFFCdjhe2Waf";
  final String ACCESS_TOKEN_SECRET = "nEvceYVOhk1AN8Zj8HrVB2mp1XUcx8kJjUoJGHNob8";

  TwitterAPI() {
    service = new ServiceBuilder()
      .provider(TwitterApi.class)
      .apiKey(CONSUMER_KEY)
      .apiSecret(CONSUMER_SECRET)
      .build();
  }

  /**
   * TODO: document this when I am in the mood...
   */
  String getTweet() {
    println("\n=== getTweet() ===============================================");

    if (!(cachedTweets.size() >= 1)) {
      int moreNeeded = batchSize;
      int additionsFromThisPass = 0;
      int fetchTries = 0;
      boolean allTheGapsHasBeenFetchedAndThereIsNoNeedToTryMore = false;
      while (fetchTries <= 10 && (1 <= (moreNeeded -= additionsFromThisPass))
             && !allTheGapsHasBeenFetchedAndThereIsNoNeedToTryMore) {
        fetchTries++;
        print("------ Attempt #"); println(fetchTries);

        // always try to fetch latest tweets first
        long fetchMaxId = -1;
        long fetchSinceId = -1;
        if (fetchTries == 1) {
          fetchMaxId = -1;
          ListIterator<TweetIdRange> fetchedIdRangesIterator = fetchedIdRanges.listIterator();
          if (fetchedIdRangesIterator.hasNext())
            fetchSinceId = fetchedIdRangesIterator.next().maxId + 1;
        } else {
          ListIterator<TweetIdRange> fetchedIdRangesIterator = fetchedIdRanges.listIterator();
          while (fetchedIdRangesIterator.hasNext()) {
            TweetIdRange currentRange = fetchedIdRangesIterator.next();

            // see if there is a gap between us.sinceId and next.maxId
            if (fetchedIdRangesIterator.hasNext()) {
              TweetIdRange nextRange = fetchedIdRangesIterator.next();
              if ((currentRange.sinceId - 1) > nextRange.maxId) {
                println(" > gap found!");
                fetchMaxId = currentRange.sinceId - 1;
                fetchSinceId = nextRange.maxId + 1;
                break;
              }

              // rewind so that we wont mess up the next pass...
              fetchedIdRangesIterator.previous();
            }

            // if we are at the end of the list and haven't found a gap yet
            // set fetchSinceId = -1 to get as much old tweets as we can
            if (!fetchedIdRangesIterator.hasNext()) {
              println(" > reached last range");
              fetchMaxId = currentRange.sinceId - 1;
              fetchSinceId = -1;
              allTheGapsHasBeenFetchedAndThereIsNoNeedToTryMore = true;
            }
          }
        }

        // fetch
        JSONArrayAndMaxIdAndSinceId tweetsAndMeta = networkFetch(fetchMaxId, 
                                                                 fetchSinceId,
                                                                 batchSize);

        // if (fetchTries == 1 && tweetsAndMeta.jsonArray.length() == 0)
        if (tweetsAndMeta.jsonArray.length() == 0 && fetchedIdRanges.size() == 0)
          break;

        additionsFromThisPass += tweetsAndMeta.jsonArray.length();

        // update range info
        long returnedMaxId = tweetsAndMeta.maxId;
        long returnedSinceId = tweetsAndMeta.sinceId;

        fetchedIdRanges.add(0, new TweetIdRange(returnedMaxId, returnedSinceId));
        printFetchedIdRanges();

        // merge range to be clean and save some space (not really)
        // TODO

        // get tweets
        JSONArray returnedStatuses = tweetsAndMeta.jsonArray;
        for (int i = 0; i < returnedStatuses.length(); i++) {
          cachedTweets.add(returnedStatuses.getJSONObject(i).getString("text"));
        }

      }
    }

    if (!(cachedTweets.size() >= 1)) {
      println("TWITTER API INTERNAL ERROR: UNABLE TO FETCH ENOUGH TWEETS");
      println("                            USE ANOTHER KEYWORD MAYBE?");
      return "@jiehanzheng says: TWITTER API ERROR: see console output.";
    }

    String tweet = cachedTweets.get(0);
    cachedTweets.remove(0);
    return teddyFilter(tweet);
  }

  JSONArrayAndMaxIdAndSinceId networkFetch(long maxId, long sinceId, int count) {
    System.out.printf(">>> TwitterAPI.networkFetch(%d,%d,%d)\n", maxId, sinceId, count);

    String requestUrl = "http://api.twitter.com/1.1/search/tweets.json" +
                        "?q=nemo" +
                        "&count=" + count +
                        "&include_entities=false" +
                        "&result_type=recent" +
                        "&lang=en";

    if (maxId >= 0)
      requestUrl += "&max_id=" + maxId;

    if (sinceId >= 0)
      requestUrl += "&since_id=" + sinceId;

    println(requestUrl);

    OAuthRequest request = new OAuthRequest(Verb.GET, requestUrl);
    service.signRequest(new Token(ACCESS_TOKEN, ACCESS_TOKEN_SECRET), request);
    Response response = request.send();

    String twitterResult = "{\"statuses\":[],\"search_metadata\":{\"max_id\": -1,\"since_id\": -1}}";
    if (response.getCode() == 200) {
      if (null == match(response.getBody(), "<title>Web Site Blocked!</title>"))
        twitterResult = response.getBody();
    }

    JSONObject jsonResult = new JSONObject(twitterResult);
    return new JSONArrayAndMaxIdAndSinceId(jsonResult.getJSONArray("statuses"),
                                           jsonResult.getJSONObject("search_metadata").getLong("max_id"),
                                           jsonResult.getJSONObject("search_metadata").getLong("since_id") == 0 ? jsonResult.getJSONArray("statuses").getJSONObject(jsonResult.getJSONArray("statuses").length()-1).getLong("id") : jsonResult.getJSONObject("search_metadata").getLong("since_id"));
  }

  String teddyFilter(String raw) {
    Pattern pattern;
    Matcher matcher;

    // line breaks
    pattern = Pattern.compile("[\n\r]+");
    matcher = pattern.matcher(raw);
    raw = matcher.replaceAll(" ");

    // <
    pattern = Pattern.compile("&lt;");
    matcher = pattern.matcher(raw);
    raw = matcher.replaceAll("<");

    // >
    pattern = Pattern.compile("&gt;");
    matcher = pattern.matcher(raw);
    raw = matcher.replaceAll(">");

    // &
    pattern = Pattern.compile("&amp;");
    matcher = pattern.matcher(raw);
    raw = matcher.replaceAll("&");

    return raw;
  }

  void printFetchedIdRanges() {
    print("--- Fetched: ");

    ListIterator<TweetIdRange> fetchedIdRangesIterator = fetchedIdRanges.listIterator();

    while(fetchedIdRangesIterator.hasNext()) {
      TweetIdRange next = fetchedIdRangesIterator.next();
      System.out.printf("(%d,%d), ", next.maxId, next.sinceId);
    }

    println();
  }
  
}


class TweetIdRange {
  public long maxId;
  public long sinceId;

  TweetIdRange(long maxId, long sinceId) {
    this.maxId = maxId;
    this.sinceId = sinceId;
  }
}


class JSONArrayAndMaxIdAndSinceId {
  JSONArray jsonArray;
  long maxId;
  long sinceId;

  JSONArrayAndMaxIdAndSinceId(JSONArray jsonArray,
                              long maxId,
                              long sinceId) {
    this.jsonArray = jsonArray;
    this.maxId = maxId;
    this.sinceId = sinceId;
  }
}
