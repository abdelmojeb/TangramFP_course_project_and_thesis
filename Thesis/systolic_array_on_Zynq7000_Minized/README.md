top entity SysA_interface_pipe1
- interface with AXI stream with data width equal the size of the precision.
- contains a state machine to receive weight matrices W,A and send C.
- 1 state machine to receive W,A and triggers computation
then waits for signal to receive new A or if busy signal is low it can receive new W.
-flags and counters control process:
    1-- jobcount number of A matrices running in the pipeline
    2-- busy indicating W is needed
    3-- count1, count2 alternating counters to track each job computation
    4-- fAcount counts 0 to N-1 to feed A matrix
    5-- store triggered by count1 and count2 to signal start storing output from the systolic array.
    6-- transfer, triggers after storing is complete to signal output transmission
- storing and transfering output is seperated from the state machine to operate whenever result is ready
A is stored in the top level while W is directed immediately to the systlic entity.
when computation starts A columns and the column exponents are directed to the systolic array and the mode selection unit module respectively each clock cycle
-The implemented block design is in bd folder, it might not be portable but the design is exported to design_1.tcl. It contains  integrating the systolic array accelerator IP to a SoC disign on Zynq7000. the operational clock for the accelerator is 30MHz.
- TangramFP files are in the TangramFP_MAC folder.
- Mode select unit is in file modes_op2_pipe1.vhd
- Systolic array stream unit is in SysA_stream_pipe1.vhd
- Systolic array interface and control in SysA_interface_pipe1_1packet.vhd
- const1.xdc constraint file is used when synthesizing the accelerator alone in the block design