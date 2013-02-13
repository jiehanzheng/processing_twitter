TwitterAPI t;

void setup() {
  t = new TwitterAPI();

  println(" > " + t.getTweet());
  println(" > " + t.getTweet());
  println(" > " + t.getTweet());
  println(" > " + t.getTweet());
  println(" > " + t.getTweet());

  println(" >>> going to sleep...");
  try{Thread.sleep(15000);}catch(Exception e){}
  println(" >>> woke up from a 15-second sleep");

  println(" > " + t.getTweet());
  println(" > " + t.getTweet());
  println(" > " + t.getTweet());
  println(" > " + t.getTweet());
  println(" > " + t.getTweet());

}