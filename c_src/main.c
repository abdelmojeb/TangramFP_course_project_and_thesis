/* main.c ---
 *
 * Filename: main.c
 * Description:
 * Author: Yuan
 * Maintainer:
 * Created: Sun Jun  2 23:14:50 2024 (+0200)
 * Version:
 * Package-Requires: ()
 * Last-Updated:
 *           By:
 *     Update #: 0
 * URL:
 * Doc URL:
 * Keywords:
 * Compatibility:
 *
 */

/* Commentary:
 *
 *
 *
 */

/* Change Log:
 *
 *
 */

/* This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.
 */

/* Code: */




//#include "../include/kacy.h"
#include "../include/kacy32.h"
#include <stdio.h>
#include <wmmintrin.h>
#include <stdint.h>
#include <inttypes.h>
#include <time.h>
#include <math.h>
#include "../include/test.h"
// extern float half_to_float(const ushort);
// extern ushort float_to_half(const float);
//extern double float_to_double(const ushort32);
double as_double(const uint64 x) ;
ushort32 double_to_float(double x);
uint32_t clmul64(uint32_t a, uint32_t b) {
    __m128i xmm_a = _mm_cvtsi64_si128(a);
    __m128i xmm_b = _mm_cvtsi64_si128(b);

    __m128i xmm_result = _mm_clmulepi64_si128(xmm_a, xmm_b, 0x00);

    uint64_t result;
    _mm_store_si128((__m128i*)&result, xmm_result);

    return result;
}
// Function to generate a random double between min and max
double random_double(double min, double max) {
    double scale = rand() / (double) RAND_MAX;
    return min + scale * (max - min);
}

// Function to calculate dot product of two vectors
double dot_product(const double* v1, const double* v2, size_t size) {
    double result = 0.0;
    for (size_t i = 0; i < size; i++) {
        result += v1[i] * v2[i];
    }
    return result;
}

int main(int argc, char **argv){

    // Welcome to the monkey testing land.

    int _branch = atoi(argv[1]);
    uint16_t a;
    uint16_t b;
    uint32_t res;

    switch(_branch){

    case 0:
        a = 0x0733;
        b = 0x05cd;
        res = a * b;
        printf("a=%#04x, b=%#04x, res = %#08x \n", a, b, res);
        // result should be: 0x29c2d7
        printf("Enter to continue \n");
        break;

    case 1:
        /* a = 0x0733; */
        /* b = 0x0001; */
        /* res = xor_mul(a, b); */
        /* printf("a=%#04x, b=%#04x, res = %#08x \n", a, b, res); */
        /* printf("Enter to continue \n"); */
        /* break; */

    case 3:
        /* // 1, Naive but representative test of xormul */
        /* res = xor_mul(a, b); */
        /* printf("res = %#08x \n", res); // result should be: 0x198827 */
        /* printf("Enter to continue \n"); */
        /* getchar(); */

        // 2, print the mul-matrix of xormul
        // uint32_t num=1, _res, i, j;
        // int max = 1024;
        // printf("\t\tTable from 1 to max: %d \n", max);
        // for(i=0; i<max; i++)
        // {
        //     printf("Table of %d \n", num);
        //     for(j=1; j<=num; j++)
        //     {
        //         _res = num * j;
        //         res = xor_mul(num, j);
        //         printf("%d x %d = %d (%d) +%d  \n",
        //                 num, j, _res, res, _res - res);
        //     }
        //     printf("\n");
        //     num++;
        // }
        // getchar();

        // 3, test Intel's clmul

        /* res = clmul64(a, b); */

        /* printf("a: %#04x \n", a); */
        /* printf("b: %#04x \n", b); */
        /* printf("res: %#08x \n", res); */
        /* printf("Enter to continue \n"); */
        /* break; */

        // The result array now contains the 128-bit CLMUL multiplication result

    case 4:
        // 4, test Karatsuba algorithm
        /* while(1){ */
        /*     uint16_t pw; */
        /*     printf("Enter pw: [0<=pw<=16]. 17 to quit\n"); */
        /*     scanf("%" SCNd16, &pw); */
        /*     if(pw == 17) */
        /*         break; */
        /*     res = mul_K(a, b, pw); */

        /*     printf("a: %#04x \n", a); */
        /*     printf("b: %#04x \n", b); */
        /*     printf("res: %#08x \n", res); */
        /* } */
        /* break; */

     case 5:
        // // 5, play with exp
        // float aa = -0.000121951104;//0.20214844;
        // float bb = -0.5;
        // float rres = 0.0;

        // printf("a: %f, b: %4f, sum: %4f \n", aa, bb, rres);

        // rres = kacy_f16_main(&aa, &bb, rres, 1, 0x10, 5, 0);

        // printf("res: %.12f \n", rres);
        // break;
    case 6:
        union {
            float f;
            uint32_t i;
        } converter;
        
        // float af = 5.96046447e-08;//0.000060975552;
        // float rsal1;
        // float rsal2;
        // ushort a_s;
        // ushort32 U = (ushort32)0x7FFFFF;

        // rsal1 = half_to_float((ushort)0x001);
        // printf("half to float: %.24f \n", rsal1);

        // rsal2 = half_to_float((ushort)0x02);//3ff
        // printf("half to float: %.24f \n", rsal2);

        // a_s =  float_to_half(0.000000029802322);
        // printf("float to half max subnormal 16: %#016llx \n", a_s);
        // a_s =  float_to_half(rsal1);
        // printf("float to half min subnormal 16: %#016llx \n", a_s);
        
        // _Float16 half_precision_number = 5.9604644775390625e-8; // Closest approximation
        // printf("Half precision float: %.24f\n", (float)half_precision_number);

        // printf("size of uint64 %d, ushort32 %d\n", sizeof(uint64), sizeof(ushort32));
        //double R =  float_to_double(U);
        //printf(" result: %.18e\nexpected %.18e", R, as_double(0x380fffffc0000000));
        converter.i =  double_to_float(0.6512984642e-45);
        printf(" result: %#016lx, float result : %18e", converter.i, converter.f);
         break;
    case 7:
        // 5, play with exp
        // float x = -0.000121951104;//0.20214844;
        // float y = -0.5;
        // double result = 0.0;

        // printf("a: %f, b: %4f, sum: %4f \n", x, y, result);

        // result = kacy_f32_main(&x, &y, result, 1, 0x10, 11, 0);

        // printf("res: %.12f \n", result);
        // printf("cast down %#016llx \n", (ushort32)0x000FFFFFF0000000);
        // break;
    
    case 8:
    union {
            double f;
            uint64_t i;
        } result;
    union {
            float f;
            uint32_t i;
        } converter1;
    union {
            float f;
            uint32_t i;
        } converter2;
    
    
     srand(time(NULL));
    
    // Vector size
    const size_t SIZE = 1000;
    
    // Allocate memory for vectors
    // double* vector1 = (double*)malloc(SIZE * sizeof(double));
    // double* vector2 = (double*)malloc(SIZE * sizeof(double));
    
    // if (vector1 == NULL || vector2 == NULL) {
    //     printf("Memory allocation failed!\n");
    //     free(vector1);
    //     free(vector2);
    //     return 1;
    // }
    float diff = 0.0;
    double sum_diff=0.0;
    double vector1;
    double vector2;
    ushort32 u;
    ushort32 v;
    // Fill vectors with random doubles between -10 and 10
    
    for (size_t i = 0; i < SIZE; i++) {
        converter1.f = ldexpf(pow(2,25)-1,(uint32_t)((rand() / (float)RAND_MAX) * 253 - 150));//ldexpf(1.0 + (rand() / (float)RAND_MAX), 127);//
        converter2.f = ldexpf(pow(2,25)-1,(uint32_t)((rand() / (float)RAND_MAX) * 253 - 150));
        //u =  double_to_float(vector1);
        //v = double_to_float(vector2);
        result.f =  kacy_fp32_mult(converter1.i, converter2.i, 0x11, 11) ;
        //printf("actual: %.18e, expected: %.18e \n ", result.f, converter1.f*converter2.f);
       // printf("v1: %.18e ,v2 : %.18e\nrand %d\n",converter1.f,converter2.f,(uint32_t)((rand() / (float)RAND_MAX) * 253 - 149));
        converter.i = double_to_float(result.f);
        diff = converter.f - (converter1.f * converter2.f);
        sum_diff=+diff;
    }
    printf("\n");
    printf("average diff: %.32f \n", diff / SIZE);
    // Calculate and print dot product
    //printf("EXPECTED product: %18.18e\n", result_exp);
    


    printf("Running MAC unit tests...\n");
    run_mac_tests(1);
    
    break;
    case 9:
        run_mac_tests(1000000);
        int min =49;
        int max = 254;
        uint8_t s;
        // for(int i = 0; i < 100; i++){
        //     s=(uint8_t)(min + (max - min)*(rand()/(float)RAND_MAX));
        //     printf("%d\n", s);
        // }
    }
    
    
    return 0;
}

/* main.c ends here */
