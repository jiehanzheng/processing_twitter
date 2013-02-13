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
import java.util.regex.*;


class TwitterAPI {

  /**
   * Debug Flag
   */
  private final boolean verbose = false;

  /**
   * Cache Size
   *
   * Always try to keep X tweets.
   */
  private int cacheSize = 100;

  /**
   * Return Threshold
   *
   * Block execution until threshold is reached.
   */
  private int blockUntil = 20;

  /**
   * Cached Tweets
   *
   * Every time <code>getTweet()</code> is called, one tweet JSONObject is taken
   * out from <code>cachedTweets</code>.  When we runs out of cached tweets, 
   * <code>getTweet()</code> will fetch more from Twitter API and store them.
   */
  private RollingStringArrayList cachedTweets = new RollingStringArrayList(cacheSize);

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
  private String consumerKey;
  private String consumerSecret;
  private String accessToken;
  private String accessTokenSecret;

  TwitterAPI(String consumerKey, 
             String consumerSecret, 
             String accessToken, 
             String accessTokenSecret) {
    this.consumerKey = consumerKey;
    this.consumerSecret = consumerSecret;
    this.accessToken = accessToken;
    this.accessTokenSecret = accessTokenSecret;

    streamInit();

    // dont return until we have some tweets
    while (cachedTweets.size() <= blockUntil) {
      try{Thread.sleep(100);}catch(Exception e){}
    }
  }

  private void streamInit() {
    ConfigurationBuilder cb = new ConfigurationBuilder();
    cb.setDebugEnabled(false)
      .setOAuthConsumerKey(consumerKey)
      .setOAuthConsumerSecret(consumerSecret)
      .setOAuthAccessToken(accessToken)
      .setOAuthAccessTokenSecret(accessTokenSecret);

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

    // filter() method internally creates a thread which manipulates TwitterStream and calls these adequate listener methods continuously.
    twitterStream.sample();
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
