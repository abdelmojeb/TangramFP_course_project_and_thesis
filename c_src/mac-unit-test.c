#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <float.h>
#include <assert.h>
#include "../include/kacy32.h"
// Function to test f32_mul function
void run_f32_mult_tests(int num_tests) {
        union {
            float f;
            uint32_t i;
        } converter;
        
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
    const size_t SIZE = num_tests;
    float diff = 0.0;
    double sum_diff=0.0;
    double vector1;
    double vector2;
    ushort32 u;
    ushort32 v;
    
    for (size_t i = 0; i < SIZE; i++) {
        converter1.f = ldexpf(pow(2,25)-1,(uint32_t)((rand() / (float)RAND_MAX) * 253 - 150));//ldexpf(1.0 + (rand() / (float)RAND_MAX), 127);//
        converter2.f = ldexpf(pow(2,25)-1,(uint32_t)((rand() / (float)RAND_MAX) * 253 - 150));
      
        result.f =  kacy_fp32_mult(converter1.i, converter2.i, 0x11, 11) ;
        
        converter.i = double_to_float(result.f);
        diff = converter.f - (converter1.f * converter2.f);
        sum_diff=+diff;
    }
    printf("\n");
    printf("average diff: %.32f \n", sum_diff / SIZE);
    
}
/*counting modes of multiplications*/
void count_modes(int threshold,float a,float b,float sum, int* full_mode_count, int* skip_bd_mode_count, int* skip_adbc_mode_count, int* skip_mode_count) {
    int expa,expb,exps;
    frexpf(a, &expa);
    frexpf(b, &expb);
    frexpf(sum, &exps);
    int exp_diff = exps - (expb+expa);
    if(exp_diff < 0){
        *full_mode_count=*full_mode_count+1;
    }else if(exp_diff == 0){
        *full_mode_count=*full_mode_count+1;
    }else if(exp_diff > 0 && exp_diff < threshold){
        *skip_bd_mode_count=*skip_bd_mode_count+1;
    }else if(exp_diff >= threshold && exp_diff < 23){
        *skip_adbc_mode_count=*skip_adbc_mode_count+1;
    }else{
        *skip_mode_count=*skip_mode_count+1;
    }
}
// Function to calculate ULP size for a given double value
double ulp_size(double x) {
    if (fabs(x) < FLT_MIN) return FLT_MIN;
    int exp;
    frexp(fabs(x), &exp);
    return ldexp(1.0, exp - 23);  // 23 is mantissa bits for float
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
    
        signa = (rand()%2)==0;
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
        signb = ((rand()%2)==0);
        mantissa_b = 0x7FFFFF*(rand()/(float)RAND_MAX);
        b_exp = min_b_exp + (max_b_exp - min_b_exp)*(rand()/(float)RAND_MAX);
        if(b_exp==0){
            b_exp = 1;
        }
        converterb.i = (signb<<31)&0x80000000|(b_exp<<23)&0x7F800000|mantissa_b&0x7FFFFF;

        ab_exp = a_exp + b_exp -127;

        min_sum_exp =  ab_exp - 33;
        max_sum_exp = 33 + ab_exp;
        if (ab_exp>221){
            max_sum_exp = 254;
        }
        if (ab_exp<33){
            min_sum_exp = 1;
        }
        int ax = EXPONENT(convertera.i);
        int bx = EXPONENT(converterb.i);
        assert (ax != 0);
        assert (bx != 0);
      
        signs = (rand()%2)==0;
        mantissa_sum = 0x7FFFFF*(rand()/(float)RAND_MAX);
        sum_exp = min_sum_exp + (max_sum_exp - min_sum_exp)*(rand()/(float)RAND_MAX);
        converters.i = (signs<<31)&0x80000000|(sum_exp<<23)&0x7F800000|mantissa_sum&0x7FFFFF;
        
        if (sum_exp - (a_exp + b_exp - 127)<0){
            printf("min = %d max = %d diff= %d\n", min_sum_exp , max_sum_exp, sum_exp - (a_exp + b_exp - 127));
           // assert(sum_exp - (a_exp + b_exp - 127) < 64 && sum_exp - (a_exp + b_exp - 127) >= 0);
        }
        *a = convertera.f;
        *b = converterb.f;
        *sum = converters.f;
}
void run_mac_tests(int num_tests, int cut) {
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
    int full_mode_count=0;
    int skip_bd_mode_count=0;
    int skip_adbc_mode_count=0;//only ac
    int skip_mode_count=0;
    for (int test = 0; test < num_tests; test++) {
        
        

        generate(&a, &b, &sum);
        a_d = (double)a;
        b_d = (double)b;
        sum_d = (double)sum;
                                                        /* skip mode debug values
                                                        a_d=a=1.123614615521247e-13;
                                                        b_d=2.492087844802879e+30;
                                                        sum_d=-9.7986553680716196e+23;*/
        expected_result = a_d * b_d+ sum;

        actual_result = kacy_f32_main(&a_d, &b_d, sum_d, 1, 0x10, cut, 0);
      /* test kacy_fp32_mult here or alternatively from run_f32_mult_tests
        convertera.f=a;
        converterb.f=b;
        //actual_result= kacy_fp32_mult( convertera.i, converterb.i, 0x11, 11);
       */
      //count modes of multiplications
      count_modes(cut, a,b,sum, &full_mode_count, &skip_bd_mode_count, &skip_adbc_mode_count, &skip_mode_count);
      
        // Calculate ULP error
        double ulp_error = ulp_difference(actual_result, expected_result);
        total_ulp_error += ulp_error;
        if (ulp_error > max_ulp_error) {
            max_ulp_error = ulp_error;
            if (ulp_error >= 0.50) {  // Log errors larger than 1 ULP
                error_count++;
                if (actual_result == sum_d){
                    printf("\nskip mode\n");
                }
                printf("Test %d - ULP Error: %.2f\n", test, ulp_error);
                printf("Expected: %.17g \n", expected_result);
                printf("Actual  : %.17g \n", actual_result);
                printf("Sample inputs that caused large error:\n");
                printf("a=%.23g , b=%.23g, sum=%.23g\n", a_d, b_d,sum_d);
            }
        }
    
    }
    // Print summary statistics
    printf("\nTest Summary:\n");
    printf("Number of tests: %d\n",num_tests);
    //printf("Vector length per test: %d\n", num_tests);
    printf("Maximum ULP error: %.2f\n", max_ulp_error);
    printf("Average ULP error: %.2f\n", total_ulp_error / num_tests);
    printf("Number of errors >1 ULP: %d\n", error_count);
    printf("modes : Full=%d Skip_bd=%d OnlyAC=%d skip=%d\n", full_mode_count, skip_bd_mode_count, skip_adbc_mode_count, skip_mode_count);
    // Categorize errors
    printf("\nError distribution:\n");
    printf("0-1 ULP   : %.2f%%\n", 100.0 * (num_tests - error_count) / num_tests);
    printf(">1 ULP    : %.2f%%\n", 100.0 * error_count / num_tests);
    

}

   