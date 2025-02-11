// Matrix-vector multiplication y = Ax.  
// A is an m rows x n columns matrix.
void matvecmul(int A[], int x[], int y[], int m, int n) {
    int sum;

    for (int i = 0; i < m; i++) {
        sum = 0;

        for (int j = 0; j < n; j++) 
            sum = sum + A[i * n + j] * x[j];

        y[i] = sum;
   }
}

void main(void) {
    int A[6] = {1, 2, 3, 4, 5, 6};
    int x[3] = {7, 8, 9};
    int y[2];
    
    matvecmul(A, x, y, 2, 3);
  }