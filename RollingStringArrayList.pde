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
    }

    al.add(s);
  }

  synchronized String pop() {
    return al.remove(al.size()-1);
  }
}
