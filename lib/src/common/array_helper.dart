int maxIndex(List<num> arr) {
  var max = 0;
  for (var i = 0; i < arr.length; i++) {
    if (arr[i] > arr[max]) {
      max = i;
    }
  }
  return max;
}
