class RollingStringArrayList {
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
      println("Removed 1 from cache");
    }

    al.add(s);
    println("New cached: " + s);
  }

  synchronized String pop() {
    if (al.size() > 0)
      return al.remove(al.size()-1);
    else
      return "Requesting too fast...";
  }
}
