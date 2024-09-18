# Task2
function insertionSort(uint[] memory x) public pure returns(uint[] memory) {
    for (uint i = 1, i < x.length; i++) {
        uint temp = x[i];
        uint j=i;
        while( (j >= 1) && (temp < x[j-1])) {
            x[j] = x[j-1];
            j--;
        }
        x[j] = temp;
    }
    return(x)
}