class RollingStringArrayList {

  /**
   * Debug Flag
   */
  private final boolean verbose = false;

  ArrayList<String> al;
  int size;

  RollingStringArrayList(int size) {
    this.size = size;
    al = new ArrayList<String>(size);
  }

  synchronized void add(String s) {
    int numToBeDeleted = al.size() - size + 1;
    while (numToBeDeleted > 0) {
      numToBeDeleted--;
      al.remove(0);
      if (verbose) println("Removed 1 from cache");
    }

    al.add(s);
    if (verbose) println("New cached: " + s);
  }

  synchronized String pop() {
    if (al.size() > 0)
      return al.remove(al.size()-1);
    else
      return "Requesting too fast...";
  }

  public int size() {
    return al.size();
  }
}
