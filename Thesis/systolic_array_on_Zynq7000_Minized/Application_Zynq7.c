
/***************************** Include Files *********************************/
#include "math.h"
#include "sleep.h"
#include "xaxidma.h"
#include "xdebug.h"
#include "xgpiops.h"
#include "xparameters.h"
#include "xtime_l.h"
#include "xuartps.h"

#ifdef __aarch64__
#include "xil_mmu.h"
#endif

#if defined(XPAR_UARTNS550_0_BASEADDR)
#include "xuartns550_l.h" /* to use uartns550 */
#endif

#if (!defined(DEBUG))
extern void xil_printf(const char* format, ...);
#endif

/******************** Constant Definitions **********************************/

/*
 * Device hardware build related constants.
 */

#define DMA_DEV_ID XPAR_AXIDMA_0_DEVICE_ID

#ifdef XPAR_AXI_7SDDR_0_S_AXI_BASEADDR
#define DDR_BASE_ADDR XPAR_AXI_7SDDR_0_S_AXI_BASEADDR
#elif defined(XPAR_MIG7SERIES_0_BASEADDR)
#define DDR_BASE_ADDR XPAR_MIG7SERIES_0_BASEADDR
#elif defined(XPAR_MIG_0_C0_DDR4_MEMORY_MAP_BASEADDR)
#define DDR_BASE_ADDR XPAR_MIG_0_C0_DDR4_MEMORY_MAP_BASEADDR
#elif defined(XPAR_PSU_DDR_0_S_AXI_BASEADDR)
#define DDR_BASE_ADDR XPAR_PSU_DDR_0_S_AXI_BASEADDR
#endif

#ifndef DDR_BASE_ADDR
#warning CHECK FOR THE VALID DDR ADDRESS IN XPARAMETERS.H, \
			DEFAULT SET TO 0x01000000
#define MEM_BASE_ADDR 0x01000000
#else
#define MEM_BASE_ADDR (DDR_BASE_ADDR + 0x1000000)
#endif

#define TX_BD_SPACE_BASE (MEM_BASE_ADDR)
#define TX_BD_SPACE_HIGH (MEM_BASE_ADDR + 0x00000FFF)
#define RX_BD_SPACE_BASE (MEM_BASE_ADDR + 0x00001000)
#define RX_BD_SPACE_HIGH (MEM_BASE_ADDR + 0x00001FFF)
#define TX_BUFFER_BASE (MEM_BASE_ADDR + 0x00100000)
#define RX_BUFFER_BASE (MEM_BASE_ADDR + 0x00300000)
#define RX_BUFFER_HIGH (MEM_BASE_ADDR + 0x004FFFFF)

// #define MAX_PKT_LEN1	1200//47040
// #define MAX_PKT_LEN_1	120//3136
// #define MAX_PKT_LEN2	40//60
#define MARK_UNCACHEABLE 0x701

#define TEST_START_VALUE 0xC
#define POLL_TIMEOUT_COUNTER 1000000U
int MAX_PKT_LEN1 = 0x8;   // 47040;0x4B0;
int MAX_PKT_LEN2 = 0x20;  // 60;0x28;//
#define EXP_MASK 0x7C00
/**************************** Type Definitions *******************************/

/************************** Function Prototypes ******************************/
#if defined(XPAR_UARTNS550_0_BASEADDR)
static void Uart550_Setup(void);
#endif

static int RxSetup(XAxiDma* AxiDmaInstPtr);
static int TxSetup(XAxiDma* AxiDmaInstPtr);
static int SendPacket(XAxiDma* AxiDmaInstPtr, u16 a[]);

static int CheckDmaResult(XAxiDma* AxiDmaInstPtr);
void getkData(void);
static int setup(void);

float as_float(const u32 x);
u32 as_uint(const float x);
u16 float_to_half(const float x);
float half_to_float(const u16 x);
/************************** Variable Definitions *****************************/
/*
 * Device instance definitions
 */
XAxiDma AxiDma;
/*****************************************************************
 *
 */
static u32 Osel_Pin1;   /* Sel button */
static u32 Ostart_Pin2; /* start button */
static u32 Olayer_Pin3; /* layer button */
static u32 Olayer_Pin4;
/*****************************************************************************/

/*---------------UART----------------------*/

XUartPs myuart;

// s32 RX_BUFFER_BASE;
volatile float y11[4] = {0};
volatile float y12[4] = {0};
volatile float y21[4] = {0};
volatile float y22[4] = {0};
// s32 Y2[10] = {0};
int DIM = 2;
int N = 4;
float W[4] = {1, 2, 3, 4};
float A[16] = {160, -15, 14, 0.13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1};
u16 W_16[4];
u16 A_16[16];
u16 Y_16[4];
int LEN = 4;
#define GPIO_DEVICE_ID XPAR_XGPIOPS_0_DEVICE_ID
// #define imageSize 784//797
XGpioPs Gpio; /* The driver instance for GPIO Device. */

int main(void) {
  setup();
  int Status;

  XGpioPs_WritePin(&Gpio, Osel_Pin1, 0x0);
  XGpioPs_WritePin(&Gpio, Ostart_Pin2, 0x0);
  XGpioPs_WritePin(&Gpio, Olayer_Pin3, 0x0);
  XGpioPs_WritePin(&Gpio, Olayer_Pin4, 0x0);
  //-------------------------------------------------------------------------------------------------------------------------------------------------------

  //-------------1st half------------//
  for (int i = 0; i < 2; i++) {
    XGpioPs_WritePin(&Gpio, Osel_Pin1, 0x1);
    XGpioPs_WritePin(&Gpio, Ostart_Pin2, 0x1);
    XGpioPs_WritePin(&Gpio, Olayer_Pin3, 0x0);
    XGpioPs_WritePin(&Gpio, Olayer_Pin4, 0x0);

    for (int i = 0; i < N; i++) {
      W_16[i] = float_to_half(W[i]);
    }
    Status = SendPacket(&AxiDma, W_16);
    if (Status != XST_SUCCESS) {
      return XST_FAILURE;
    }
    printf("sending W data ...\n");
    for (int i = 0; i < DIM; i++) {
      for (int j = 0; j < DIM; j++) {
        printf("%f, ", W[DIM * i + j]);
      }
      printf("\n");
    }

    printf("sending A data ...\n");
    for (int tile = 0; tile < 4; tile++) {
      for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
          printf("%f, ", A[DIM * i + j + DIM * DIM * tile]);
        }
        printf("\n");
      }
      printf("\n");
    }
    printf("expected result ...\n");
    float temp = 0;
    for (int tile = 0; tile < 4; tile++) {
      for (int i = 0; i < DIM; i++) {
        for (int j = 0; j < DIM; j++) {
          for (int k = 0; k < DIM; k++) {
            temp = temp + W[DIM * i + k] * A[j + DIM * k + DIM * DIM * tile];
          }
          printf("%f, ", temp);
          temp = 0;
        }
        printf("\n");
      }
      printf("\n");
    }
    XGpioPs_WritePin(&Gpio, Osel_Pin1, 0x0);
    MAX_PKT_LEN1 = 0x20;
    for (int i = 0; i < 16; i++) {
      A_16[i] = float_to_half(A[i]);
    }
    Status = SendPacket(&AxiDma, A_16);

    Status = CheckDmaResult(&AxiDma);
    Status = CheckDmaResult(&AxiDma);
    Status = CheckDmaResult(&AxiDma);
    getkData();

    printf("getting data ...\n");
    printf("y11 ...\n");
    for (int i = 0; i < DIM; i++) {
      for (int j = 0; j < DIM; j++) {
        printf("%f, ", y11[DIM * i + j]);
      }
      printf("\n");
    }
    printf("y12 ...\n");
    for (int i = 0; i < DIM; i++) {
      for (int j = 0; j < DIM; j++) {
        printf("%f, ", y12[DIM * i + j]);
      }
      printf("\n");
    }
    printf("y21 ...\n");
    for (int i = 0; i < DIM; i++) {
      for (int j = 0; j < DIM; j++) {
        printf("%f, ", y21[DIM * i + j]);
      }
      printf("\n");
    }
    printf("y22 ...\n");
    for (int i = 0; i < DIM; i++) {
      for (int j = 0; j < DIM; j++) {
        printf("%f, ", y22[DIM * i + j]);
      }
      printf("\n");
    }
    XGpioPs_WritePin(&Gpio, Osel_Pin1, 0x0);
    XGpioPs_WritePin(&Gpio, Ostart_Pin2, 0x0);
    XGpioPs_WritePin(&Gpio, Olayer_Pin3, 0x0);
    XGpioPs_WritePin(&Gpio, Olayer_Pin4, 0x0);
  }
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
    printf("operation failed");
  } else {
    return XST_SUCCESS;
  }
}

/*****************************************************************************/
/**
 *
 * This function sets up RX channel of the DMA engine to be ready for packet
 * reception
 *
 * @param	AxiDmaInstPtr is the pointer to the instance of the DMA engine.
 *
 * @return	XST_SUCCESS if the setup is successful, XST_FAILURE otherwise.
 *
 * @note		None.
 *
 ******************************************************************************/
static int RxSetup(XAxiDma* AxiDmaInstPtr) {
  XAxiDma_BdRing* RxRingPtr;
  int Delay = 0;
  int Coalesce = 1;
  int Status;
  XAxiDma_Bd BdTemplate;
  XAxiDma_Bd* BdPtr;
  XAxiDma_Bd* BdCurPtr;
  u32 BdCount;
  UINTPTR RxBufferPtr;

  RxRingPtr = XAxiDma_GetRxRing(AxiDmaInstPtr);

  /* Disable all RX interrupts before RxBD space setup */

  XAxiDma_BdRingIntDisable(RxRingPtr, XAXIDMA_IRQ_ALL_MASK);

  /* Set delay and coalescing */
  XAxiDma_BdRingSetCoalesce(RxRingPtr, Coalesce, Delay);

  /* Setup Rx BD space */
  BdCount = XAxiDma_BdRingCntCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT,
                                  RX_BD_SPACE_HIGH - RX_BD_SPACE_BASE + 1);

  Status = XAxiDma_BdRingCreate(RxRingPtr, RX_BD_SPACE_BASE, RX_BD_SPACE_BASE,
                                XAXIDMA_BD_MINIMUM_ALIGNMENT, BdCount);

  if (Status != XST_SUCCESS) {
    xil_printf("RX create BD ring failed %d\r\n", Status);

    return XST_FAILURE;
  }

  /*
   * Setup an all-zero BD as the template for the Rx channel.
   */
  XAxiDma_BdClear(&BdTemplate);

  Status = XAxiDma_BdRingClone(RxRingPtr, &BdTemplate);
  if (Status != XST_SUCCESS) {
    xil_printf("RX clone BD failed %d\r\n", Status);

    return XST_FAILURE;
  }

  /* Attach buffers to RxBD ring so we are ready to receive packets */

  Status = XAxiDma_BdRingAlloc(RxRingPtr, 1, &BdPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("RX alloc BD failed %d\r\n", Status);

    return XST_FAILURE;
  }

  Status = XAxiDma_BdSetBufAddr(BdPtr, RX_BUFFER_BASE);

  if (Status != XST_SUCCESS) {
    xil_printf("Set buffer addr %x on BD %x failed %d\r\n",
               (unsigned int)RX_BUFFER_BASE, (UINTPTR)BdPtr, Status);

    return XST_FAILURE;
  }

  Status = XAxiDma_BdSetLength(BdPtr, MAX_PKT_LEN2, RxRingPtr->MaxTransferLen);
  if (Status != XST_SUCCESS) {
    xil_printf("Rx set length %d on BD %x failed %d\r\n", MAX_PKT_LEN2,
               (UINTPTR)BdPtr, Status);

    return XST_FAILURE;
  }

  /* Receive BDs do not need to set anything for the control
   * The hardware will set the SOF/EOF bits per stream status
   */
  XAxiDma_BdSetCtrl(BdPtr, 0);
  XAxiDma_BdSetId(BdPtr, RX_BUFFER_BASE);

  /* Clear the receive buffer, so we can verify data
   */
  memset((void*)RX_BUFFER_BASE, 0, MAX_PKT_LEN2);

  Status = XAxiDma_BdRingToHw(RxRingPtr, 1, BdPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("RX submit hw failed %d\r\n", Status);

    return XST_FAILURE;
  }
  Status = XAxiDma_BdRingStart(RxRingPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("RX start hw failed %d\r\n", Status);

    return XST_FAILURE;
  }

  return XST_SUCCESS;
}

/*****************************************************************************/
/**
 *
 * This function sets up the TX channel of a DMA engine to be ready for packet
 * transmission
 *
 * @param	AxiDmaInstPtr is the instance pointer to the DMA engine.
 *
 * @return	XST_SUCCESS if the setup is successful, XST_FAILURE otherwise.
 *
 * @note		None.
 *
 ******************************************************************************/
static int TxSetup(XAxiDma* AxiDmaInstPtr) {
  XAxiDma_BdRing* TxRingPtr;
  XAxiDma_Bd BdTemplate;
  int Delay = 0;
  int Coalesce = 1;
  int Status;
  u32 BdCount;

  TxRingPtr = XAxiDma_GetTxRing(AxiDmaInstPtr);

  /* Disable all TX interrupts before TxBD space setup */

  XAxiDma_BdRingIntDisable(TxRingPtr, XAXIDMA_IRQ_ALL_MASK);

  /* Set TX delay and coalesce */
  XAxiDma_BdRingSetCoalesce(TxRingPtr, Coalesce, Delay);

  /* Setup TxBD space  */
  BdCount = XAxiDma_BdRingCntCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT,
                                  TX_BD_SPACE_HIGH - TX_BD_SPACE_BASE + 1);

  Status = XAxiDma_BdRingCreate(TxRingPtr, TX_BD_SPACE_BASE, TX_BD_SPACE_BASE,
                                XAXIDMA_BD_MINIMUM_ALIGNMENT, BdCount);
  if (Status != XST_SUCCESS) {
    xil_printf("failed create BD ring in txsetup\r\n");

    return XST_FAILURE;
  }

  /*
   * We create an all-zero BD as the template.
   */
  XAxiDma_BdClear(&BdTemplate);

  Status = XAxiDma_BdRingClone(TxRingPtr, &BdTemplate);
  if (Status != XST_SUCCESS) {
    xil_printf("failed bdring clone in txsetup %d\r\n", Status);

    return XST_FAILURE;
  }

  /* Start the TX channel */
  Status = XAxiDma_BdRingStart(TxRingPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("failed start bdring txsetup %d\r\n", Status);

    return XST_FAILURE;
  }

  return XST_SUCCESS;
}

/*****************************************************************************/
/**
 *
 * This function transmits one packet non-blockingly through the DMA engine.
 *
 * @param	AxiDmaInstPtr points to the DMA engine instance
 *
 * @return	- XST_SUCCESS if the DMA accepts the packet successfully,
 *		- XST_FAILURE otherwise.
 *
 * @note     None.
 *
 ******************************************************************************/
static int SendPacket(XAxiDma* AxiDmaInstPtr, u16 a[]) {
  XAxiDma_BdRing* TxRingPtr;
  u16* TxPacket;
  u16* Packet = (u16*)a;
  // s32 Value;
  XAxiDma_Bd* BdPtr;
  int Status;
  int Index;
  int ProcessedBdCount;
  int TimeOut = POLL_TIMEOUT_COUNTER;
  TxRingPtr = XAxiDma_GetTxRing(AxiDmaInstPtr);

  /* Create pattern in the packet to transmit */
  TxPacket = a;  // Packet;

  /* Flush the buffers before the DMA transfer, in case the Data Cache
   * is enabled
   */
  Xil_DCacheFlushRange((UINTPTR)TxPacket, MAX_PKT_LEN1);
  Xil_DCacheFlushRange((UINTPTR)RX_BUFFER_BASE, MAX_PKT_LEN2);

  /* Allocate a BD */
  Status = XAxiDma_BdRingAlloc(TxRingPtr, 1, &BdPtr);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  /* Set up the BD using the information of the packet to transmit */
  Status = XAxiDma_BdSetBufAddr(BdPtr, (UINTPTR)Packet);
  if (Status != XST_SUCCESS) {
    xil_printf("Tx set buffer addr %x on BD %x failed %d\r\n", (UINTPTR)Packet,
               (UINTPTR)BdPtr, Status);

    return XST_FAILURE;
  }

  Status = XAxiDma_BdSetLength(BdPtr, MAX_PKT_LEN1, TxRingPtr->MaxTransferLen);
  if (Status != XST_SUCCESS) {
    xil_printf("Tx set length %d on BD %x failed %d\r\n", MAX_PKT_LEN1,
               (UINTPTR)BdPtr, Status);

    return XST_FAILURE;
  }

#if (XPAR_AXIDMA_0_SG_INCLUDE_STSCNTRL_STRM == 1)
  Status = XAxiDma_BdSetAppWord(BdPtr, XAXIDMA_LAST_APPWORD, MAX_PKT_LEN1);

  /* If Set app length failed, it is not fatal
   */
  if (Status != XST_SUCCESS) {
    xil_printf("Set app word failed with %d\r\n", Status);
  }
#endif

  /* For single packet, both SOF and EOF are to be set
   */
  XAxiDma_BdSetCtrl(BdPtr,
                    XAXIDMA_BD_CTRL_TXEOF_MASK | XAXIDMA_BD_CTRL_TXSOF_MASK);

  XAxiDma_BdSetId(BdPtr, (UINTPTR)Packet);

  /* Give the BD to DMA to kick off the transmission. */
  Status = XAxiDma_BdRingToHw(TxRingPtr, 1, BdPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("to hw failed %d\r\n", Status);
    return XST_FAILURE;
  }
  // wait untill all data has been sent!
  while (TimeOut) {
    if ((ProcessedBdCount =
             XAxiDma_BdRingFromHw(TxRingPtr, XAXIDMA_ALL_BDS, &BdPtr)) != 0) {
      break;
    }
    TimeOut--;
    usleep(1U);
  }
  // printf("TimeOut %d", TimeOut);
  /* Free all processed TX BDs for future transmission */
  Status = XAxiDma_BdRingFree(TxRingPtr, ProcessedBdCount, BdPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("Failed to free %d tx BDs %d\r\n", ProcessedBdCount, Status);
    return XST_FAILURE;
  }

  return XST_SUCCESS;
}

/******************************************************************************/
void getkData(void) {
  u16* RxPacket;
  int Index = 0;

  printf("I am in getData\n");
  RxPacket = (u16*)RX_BUFFER_BASE;
  //	printf("bits hex %X", &RxPacket);

  /* Invalidate the DestBuffer before receiving the data, in case the
   * Data Cache is enabled
   */
  //	Xil_DCacheInvalidateRange((UINTPTR)RxPacket, MAX_PKT_LEN2*NUM_RX_PKTS);
  //	printf("received data hex \n");
  for (Index = 0; Index < LEN; Index++) {
    y11[Index] = half_to_float(RxPacket[Index]);
    y12[Index] = half_to_float(RxPacket[Index + LEN]);
    y21[Index] = half_to_float(RxPacket[Index + LEN * 2]);
    y22[Index] = half_to_float(RxPacket[Index + LEN * 3]);
    //		printf("%X, \n",  RxPacket[Index]);
  }
  // return XST_SUCCESS;
}
/*****************************************************************************/
/**
 *
 * This function waits until the DMA transaction is finished, checks data,
 * and cleans up.
 *
 * @param	None
 *
 * @return	- XST_SUCCESS if DMA transfer is successful and data is correct,
 *		- XST_FAILURE if fails.
 *
 * @note		None.
 *
 ******************************************************************************/
static int CheckDmaResult(XAxiDma* AxiDmaInstPtr) {
  XAxiDma_BdRing* TxRingPtr;
  XAxiDma_BdRing* RxRingPtr;
  XAxiDma_Bd* BdPtr;
  int ProcessedBdCount;
  int FreeBdCount;
  int Status;
  int TimeOut = POLL_TIMEOUT_COUNTER;

  TxRingPtr = XAxiDma_GetTxRing(AxiDmaInstPtr);
  RxRingPtr = XAxiDma_GetRxRing(AxiDmaInstPtr);

  TimeOut = POLL_TIMEOUT_COUNTER;

  /*
   * Wait until the data has been received by the Rx channel or
   * 1usec * 10^6 iterations of timeout occurs.
   */
  while (TimeOut) {
    if ((ProcessedBdCount =
             XAxiDma_BdRingFromHw(RxRingPtr, XAXIDMA_ALL_BDS, &BdPtr)) != 0)
      break;
    TimeOut--;
    usleep(1U);
  }
  if (TimeOut == 0) {
    printf("the receiving is timed out\n\n");
  }

  /*------------------------------------ Check received data
   * -----------------------------------------------*/

  Xil_DCacheInvalidateRange((UINTPTR)RX_BUFFER_BASE, MAX_PKT_LEN2);

  /* Free all processed RX BDs for future transmission */
  Status = XAxiDma_BdRingFree(RxRingPtr, ProcessedBdCount, BdPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("Failed to free %d rx BDs %d\r\n", ProcessedBdCount, Status);
    return XST_FAILURE;
  }

  /* Return processed BDs to RX channel so we are ready to receive new
   * packets:
   *    - Allocate all free RX BDs
   *    - Pass the BDs to RX channel
   */
  FreeBdCount = XAxiDma_BdRingGetFreeCnt(RxRingPtr);

  Status = XAxiDma_BdRingAlloc(RxRingPtr, 1, &BdPtr);
  if (Status == XST_FAILURE || Status == XST_INVALID_PARAM) {
    xil_printf("bd alloc failed---%d\r\n", Status);
    return XST_FAILURE;
  }

  Status = XAxiDma_BdSetBufAddr(BdPtr, RX_BUFFER_BASE);

  if (Status != XST_SUCCESS) {
    xil_printf("Set buffer addr %x on BD %x failed %d\r\n",
               (unsigned int)RX_BUFFER_BASE, (UINTPTR)BdPtr, Status);

    return XST_FAILURE;
  }

  Status = XAxiDma_BdSetLength(BdPtr, MAX_PKT_LEN2, RxRingPtr->MaxTransferLen);
  if (Status != XST_SUCCESS) {
    xil_printf("Rx set length %d on BD %x failed %d\r\n", MAX_PKT_LEN2,
               (UINTPTR)BdPtr, Status);

    return XST_FAILURE;
  }
  XAxiDma_BdSetCtrl(BdPtr, 0);
  XAxiDma_BdSetId(BdPtr, RX_BUFFER_BASE);

  Status = XAxiDma_BdRingToHw(RxRingPtr, 1, BdPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("Submit %d rx BDs failed %d\r\n", 1, Status);
    return XST_FAILURE;
  }

  return XST_SUCCESS;
}

/*setting up AxiDma, GPIO, and UART*/
/*******************************************************************/
static int setup(void) {
  int Status;
  /*--------------AxiDma---------------------*/
  XAxiDma_Config* Config;
  Config = XAxiDma_LookupConfig(DMA_DEV_ID);
  if (!Config) {
    xil_printf("No config found for %d\r\n", DMA_DEV_ID);

    return XST_FAILURE;
  }

  /* Initialize DMA engine */
  Status = XAxiDma_CfgInitialize(&AxiDma, Config);
  if (Status != XST_SUCCESS) {
    xil_printf("Initialization failed %d\r\n", Status);
    return XST_FAILURE;
  }

  if (!XAxiDma_HasSg(&AxiDma)) {
    xil_printf("Device configured as Simple mode \r\n");

    return XST_FAILURE;
  }

  Status = TxSetup(&AxiDma);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }
  // RX_BUFFER_BASE=y11;
  Status = RxSetup(&AxiDma);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  /*--------------GPIO-----------------------*/
  // GPIO configuration-----------------------------------------------
  Osel_Pin1 = 54;
  Ostart_Pin2 = 55;
  Olayer_Pin3 = 56;
  Olayer_Pin4 = 57;

  /* Initialize the GPIO driver. */  //------------------------------------
  XGpioPs_Config* ConfigPtr;
  ConfigPtr = XGpioPs_LookupConfig(GPIO_DEVICE_ID);
  //	Type_of_board = XGetPlatform_Info();

  Status = XGpioPs_CfgInitialize(&Gpio, ConfigPtr, ConfigPtr->BaseAddr);
  XGpioPs_SetDirectionPin(&Gpio, Osel_Pin1, 1);
  XGpioPs_SetOutputEnablePin(&Gpio, Osel_Pin1, 1);

  XGpioPs_SetDirectionPin(&Gpio, Ostart_Pin2, 1);
  XGpioPs_SetOutputEnablePin(&Gpio, Ostart_Pin2, 1);

  XGpioPs_SetDirectionPin(&Gpio, Olayer_Pin3, 1);
  XGpioPs_SetOutputEnablePin(&Gpio, Olayer_Pin3, 1);

  XGpioPs_SetDirectionPin(&Gpio, Olayer_Pin4, 1);
  XGpioPs_SetOutputEnablePin(&Gpio, Olayer_Pin4, 1);

  /*---------------UART----------------------*/
  XUartPs_Config* myuartconfig;

  myuartconfig = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
  Status =
      XUartPs_CfgInitialize(&myuart, myuartconfig, myuartconfig->BaseAddress);
  if (Status != XST_SUCCESS) {
    xil_printf("Initialization failed\n\r");
  }
  Status = XUartPs_SetBaudRate(&myuart, 921600);
  if (Status != XST_SUCCESS) {
    xil_printf("BaudRateInitialization failed\n\r");
  }
  XUartPsFormat param;
  XUartPs_GetDataFormat(&myuart, &param);
  /*---------------------------------------*/
  return XST_SUCCESS;
}
u32 as_uint(const float x) { return *(u32*)&x; }
float as_float(const u32 x) { return *(float*)&x; }

float half_to_float(const u16 x) {
  //    /* IEEE-754 16-bit floating-point
  //       format (without infinity):
  //       1-5-10, exp-15, +-131008.0,
  //       +-6.1035156E-5, +-5.9604645E-8,
  //       3.311 digits */
  const u32 e = (x & EXP_MASK) >> 10;  // exponent
  const u32 m = (x & 0x03FF) << 13;    // mantissa
  const u32 v =
      as_uint((float)m) >> 23;  // evil log2 bit hack to count
                                // leading zeros in denormalized format
  return as_float((x & 0x8000) << 16 | (e != 0) * ((e + 112) << 23 | m) |
                  ((e == 0) & (m != 0)) *
                      ((v - 37) << 23 | ((m << (150 - v)) & 0x007FE000)));
  // sign : normalized : denormalized
}

u16 float_to_half(const float x) {
  /* IEEE-754 16-bit floating-point
     format (without infinity):
     1-5-10, exp-15, +-131008.0,
     +-6.1035156E-5, +-5.9604645E-8,
     3.311 digits */
  const u32 b =
      as_uint(x) + 0x00001000;  // round-to-nearest-even:
                                // add last bit after truncated mantissa
  const u32 e = (b & 0x7F800000) >> 23;  // exponent
  const u32 m = b & 0x007FFFFF;          /* mantissa; in line below:
                                             0x007FF000 = 0x00800000-0x00001000 =
                                             decimal indicator flag - initial rounding */
  return (b & 0x80000000) >> 16 |
         (e > 112) * ((((e - 112) << 10) & EXP_MASK) | m >> 13) |
         ((e < 113) & (e > 101)) *
             ((((0x007FF000 + m) >> (125 - e)) + 1) >> 1) |
         (e > 143) * 0x7FFF;  // sign : normalized : denormalized : saturate
}
