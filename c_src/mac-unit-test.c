#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <float.h>
#include <assert.h>
#include "../include/kacy32.h"

// Function to calculate ULP size for a given double value
double ulp_size(double x) {
    if (fabs(x) < FLT_MIN) return FLT_MIN;
    int exp;
    frexp(fabs(x), &exp);
    //printf("neibour_no = %f\n", ldexpf(1.0, exp - 23));
    return ldexpf(1.0, exp - 23);  // 52 is mantissa bits for double
}

// Function to calculate error in ULPs
double ulp_difference(double actual, double expected) {
    if (actual == expected) return 0.0;
    if (isnan(actual) || isnan(expected)) return DBL_MAX;
    if (isinf(actual) || isinf(expected)) return DBL_MAX;
    
    double ulp = ulp_size(expected);
    return fabs(actual - expected) / ulp;
}

// Function to generate test value in different ranges
double generate_test_value(int category) {
    double val;
    switch(category) {
        case 0: // Small numbers around float32 minimum
            return ldexpf(1.0 + (rand() / (double)RAND_MAX), -127);
            
        case 1: // Normal numbers in float32 range
            return (rand() / (double)RAND_MAX) * 100.0 - 50.0;
            
        case 2: // Large numbers around float32 maximum
            return ldexpf(1.0 + (rand() / (double)RAND_MAX), 127);
            
        case 3: // Numbers that might cause rounding issues
            val = 1.0;
            for(int i = 0; i < 24; i++) {
                if(rand() % 2) {
                    val += ldexpf(1.0, -i);
                }
            }
            return val;
            
        case 4: // Subnormal numbers
            return ldexpf(rand() / (double)RAND_MAX, -149);
            
        default:
            return rand() / (double)RAND_MAX;
    }
}
void generate(float *a, float *b, float *sum) {
    int signa,signb, signs;
    int32_t min_sum_exp, max_sum_exp, min_b_exp,max_b_exp;
    
    uint32_t mantissa_a;
    uint32_t mantissa_b;
    uint32_t mantissa_sum;
	uint32_t a_exp, b_exp, sum_exp, ab_exp;
    union {
        uint32_t i;
        float f;
    } convertera;
    union {
        uint32_t i;
        float f;
    } converterb;
    union {
        uint32_t i;
        float f;
    } converters;
    
        signa = (rand()%2)==0;//pow((-1),(rand()%2));
        mantissa_a = 0x7FFFFF*(rand()/(float)RAND_MAX);
        a_exp = 0xFE*(rand()/(float)RAND_MAX);
        if(a_exp==0){
            a_exp = 1;
        }
        convertera.i = (signa<<31)&0x80000000|(a_exp<<23)&0x7F800000|mantissa_a&0x7FFFFF;
        
        if(a_exp<127){
            min_b_exp =  127 - a_exp;
            max_b_exp = 254;
        }else{
            min_b_exp = 1;
            max_b_exp = 254 - a_exp;
        }
        signb = ((rand()%2)==0);//pow((-1),(rand()%2));
        mantissa_b = 0x7FFFFF*(rand()/(float)RAND_MAX);
        b_exp = min_b_exp + (max_b_exp - min_b_exp)*(rand()/(float)RAND_MAX);
        if(b_exp==0){
            b_exp = 1;
        }
        converterb.i = (signb<<31)&0x80000000|(b_exp<<23)&0x7F800000|mantissa_b&0x7FFFFF;

        ab_exp = a_exp + b_exp -127;

        min_sum_exp =  ab_exp - 63;
        max_sum_exp = 63 + ab_exp;
        if (ab_exp>191){
            max_sum_exp = 254;
        }
        if (ab_exp<63){
            min_sum_exp = 1;
        }
        int ax = EXPONENT(convertera.i);
        int bx = EXPONENT(converterb.i);
        assert (ax != 0);
        assert (bx != 0);
      
        signs = (rand()%2)==0;//pow((-1),(rand()%2));
        mantissa_sum = 0x7FFFFF*(rand()/(float)RAND_MAX);
        sum_exp = min_sum_exp + (max_sum_exp - min_sum_exp)*(rand()/(float)RAND_MAX);
        converters.i = (signs<<31)&0x80000000|(sum_exp<<23)&0x7F800000|mantissa_sum&0x7FFFFF;
        //printf("axp = %d bxp = %d axbx= %d sum_exp = %d\n", a_exp , b_exp, a_exp + b_exp -127, sum_exp );
        if (sum_exp - (a_exp + b_exp - 127)>=64){
            //printf("min = %d max = %d diff= %d\n", min_sum_exp , max_sum_exp, sum_exp - (a_exp + b_exp - 127) );
        }
        *a = convertera.f;
        *b = converterb.f;
        *sum = converters.f;
}
void run_mac_tests(int num_tests) {
    int error_count = 0;
    double total_ulp_error = 0.0;
    double max_ulp_error = 0.0;
    double expected_result = 0.0;
    double actual_result = 0.0;
    double a_d, b_d, sum_d;
    float a,b,sum;
    union {
        uint32_t i;
        float f;
    } convertera;
    union {
        uint32_t i;
        float f;
    } converterb;
    
    for (int test = 0; test < num_tests; test++) {
        
   
        generate(&a, &b, &sum);
        a_d = (double)a;
        b_d = (double)b;
        sum_d = (double)sum;
        expected_result = a_d * b_d+ sum_d;

        actual_result = kacy_f32_main(&a_d, &b_d, sum_d, 1, 0x10, 11, 0);
        convertera.f=a;
        converterb.f=b;
        //actual_result= kacy_fp32_mult( convertera.i, converterb.i, 0x11, 11);
        // Calculate ULP error
        double ulp_error = ulp_difference(actual_result, expected_result);
        total_ulp_error += ulp_error;
        if (ulp_error > max_ulp_error) {
            max_ulp_error = ulp_error;
            if (ulp_error >= 0.250) {  // Log errors larger than 1 ULP
                error_count++;
                printf("\nTest %d - ULP Error: %.2f\n", test, ulp_error);
                printf("Expected: %.17g \n", expected_result
                       );
                printf("Actual  : %.17g \n", actual_result
                       );
                printf("Sample inputs that caused large error:\n");
                //for(int i = 0; i < fmin(5, num_tests); i++) {  // Show first 5 inputs
                    printf("a=%.17g , b=%.17g, sum=%.17g\n", 
                            a,b,sum);
                //}
            }
        }
    
    }
    // Print summary statistics
    printf("\nTest Summary:\n");
    printf("Number of tests: 100\n");
    printf("Vector length per test: %d\n", num_tests);
    printf("Maximum ULP error: %.2f\n", max_ulp_error);
    printf("Average ULP error: %.2f\n", total_ulp_error / 100);
    printf("Number of errors >1 ULP: %d\n", error_count);
    
    // Categorize errors
    printf("\nError distribution:\n");
    printf("0-1 ULP   : %.2f%%\n", 100.0 * (100 - error_count) / 100);
    printf(">1 ULP    : %.2f%%\n", 100.0 * error_count / 100);
    

}

   