/**
 *
 * EXCERPT FROM http://code.google.com/p/processing/wiki/LibraryOverview
 * =====================================================================
 * 
 * Using the code folder
 * ---------------------
 *
 * If all you want to do is add some Java code to a sketch, sometimes you don't 
 * even need to build a full library. If you add a .jar file to your sketch 
 * (using Sketch → Add File), the file will be copied to a folder named code 
 * inside your sketch folder. When running the sketch, all packages found in the
 * .jar file will automatically be added as import statements in the sketch 
 * (though invisible to the user).
 *
 */

import java.util.ArrayList;
import java.util.Arrays;
import java.net.URLEncoder;


class TwitterAPI {

  /**
   * Cache Size
   *
   * Always try to keep X tweets.
   */
  private int cacheSize = 100;

  /**
   * Cached Tweets
   *
   * Every time <code>getTweet()</code> is called, one tweet JSONObject is taken
   * out from <code>cachedTweets</code>.  When we runs out of cached tweets, 
   * <code>getTweet()</code> will fetch more from Twitter API and store them.
   */
  private RollingStringArrayList cachedTweets;

  /**
   * Twitter stuff
   *
   * It would make sense if Google Docs / FusionTables asked for OAuth
   * authentication, but why do I have to be OAuth-authenticated to search 
   * Twitter...  Why not just use IP-based rate limiting...
   *
   * Do not abuse my keys...  anyone using this combination shares the 
   * 180reqs/15mins quota, or the 1-stream-at-all-times limit.
   */
  private final String CONSUMER_KEY = "BMJAwlAKgDEw1MrgZqfHqQ";
  private final String CONSUMER_SECRET = "GM59Nr4c296Tqog74lNGBzai1za5CgrvlwRc3nnY2Cg";
  private final String ACCESS_TOKEN = "34873459-B3GQy8y6d3iRN5UV24ys3ErL62j5tAFFCdjhe2Waf";
  private final String ACCESS_TOKEN_SECRET = "nEvceYVOhk1AN8Zj8HrVB2mp1XUcx8kJjUoJGHNob8";

  TwitterAPI() {
    this("mad at");
  }

  TwitterAPI(String track) {
    cachedTweets = new RollingStringArrayList(cacheSize);

    ArrayList<String> trackList = new ArrayList<String>();
    trackList.add(track);

    try {
      prefillCache(track, cacheSize);
    } catch (Exception e) {}
    streamInit(trackList);
  }

  private void streamInit(ArrayList<String> track) {
    ConfigurationBuilder cb = new ConfigurationBuilder();
    cb.setDebugEnabled(true)
      .setOAuthConsumerKey(CONSUMER_KEY)
      .setOAuthConsumerSecret(CONSUMER_SECRET)
      .setOAuthAccessToken(ACCESS_TOKEN)
      .setOAuthAccessTokenSecret(ACCESS_TOKEN_SECRET);

    TwitterStream twitterStream = new TwitterStreamFactory(cb.build()).getInstance();

    StatusListener listener = new StatusListener() {
      public void onStatus(Status status) {
        // System.out.println(/*"@" + status.getUser().getScreenName() + ": " + */status.getText());
        cachedTweets.add(status.getText());
      }

      public void onTrackLimitationNotice(int numberOfLimitedStatuses) {
        System.out.println("Got track limitation notice:" + numberOfLimitedStatuses);
      }

      public void onStallWarning(StallWarning warning) {
        System.out.println("Got stall warning:" + warning);
      }

      public void onException(Exception ex) {
        ex.printStackTrace();
      }

      // omg do i really have to implement these...
      public void onDeletionNotice(StatusDeletionNotice statusDeletionNotice) {}
      public void onScrubGeo(long userId, long upToStatusId) {}
  };

    twitterStream.addListener(listener);
    String[] trackArray = track.toArray(new String[track.size()]);

    // filter() method internally creates a thread which manipulates TwitterStream and calls these adequate listener methods continuously.
    FilterQuery fq = new FilterQuery();
    fq.track(trackArray);

    twitterStream.filter(fq);
  }

  private void prefillCache(String q, int count) throws JSONException,
                                                UnsupportedEncodingException {
    String requestUrl = "http://api.twitter.com/1.1/search/tweets.json" +
                        "?q=" + URLEncoder.encode(q, "UTF-8") +
                        "&count=" + count +
                        "&include_entities=false" +
                        "&result_type=recent" +
                        "&lang=en";

    println(requestUrl);

    OAuthRequest request = new OAuthRequest(Verb.GET, requestUrl);
    OAuthService service = new ServiceBuilder()
      .provider(TwitterApi.class)
      .apiKey(CONSUMER_KEY)
      .apiSecret(CONSUMER_SECRET)
      .build();
    service.signRequest(new Token(ACCESS_TOKEN, ACCESS_TOKEN_SECRET), request);
    Response response = request.send();

    String twitterResult = "{\"statuses\":[],\"search_metadata\":{\"max_id\": -1,\"since_id\": -1}}";
    if (response.getCode() == 200) {
      if (null == match(response.getBody(), "<title>Web Site Blocked!</title>"))
        twitterResult = response.getBody();
    }

    JSONObject jsonResult = new JSONObject(twitterResult);
    JSONArray returnedStatuses = jsonResult.getJSONArray("statuses");
    for (int i = returnedStatuses.length()-1; i >= 0; i--) {
      cachedTweets.add(returnedStatuses.getJSONObject(i).getString("text"));
    }
  }

  String getTweet() {
    return teddyFilter(cachedTweets.pop());
  }

  private String teddyFilter(String raw) {
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
}
