##Information about used Phoronix Test Suite Test:



### build-linux-kernel (Processor)
This test times how long it takes to build the Linux 3.18 kernel.  

- Embassy Time: 7 minutes

### c-ray (Processor)
This is a test of C-Ray, a simple raytracer designed to test the floating-point CPU performance. This test is multi-threaded (16 threads per core), will shoot 8 rays per pixel for anti-aliasing, and will generate a 1600 x 1200 image.  
This test profile relies upon the following shared libraries:
linux-vdso.so.1, libm.so.6, libpthread.so.0, libc.so.6  
This test profile can be built with CPU instruction set extension support including: MMX, AVX, FMA, FMA4, OTHER  

- Embassy : 2 minutes

### fourstones (Processor)
This integer benchmark solves positions in the game of connect-4, as played on a vertical 7x6 board. By default, it uses a 64Mb transposition table with the twobig replacement strategy.  
Positions are represented as 64-bit bitboards, and the hash function is computed using a single 64-bit modulo operation, giving 64-bit machines a slight edge. The alpha-beta searcher sorts moves dynamically based on the history heuristic.  

- Embassy Time: 7 minutes

### pybench (System)
This test profile reports the total time of the different average timed test results from PyBench.  
PyBench reports average test times for different functions such as BuiltinFunctionCalls and NestedForLoops, with this total result providing a rough estimate as to Python's average performance on a given system.  
This test profile runs PyBench each time for 20 rounds.

- Embassy Time: 3 minutes

### smallpt (Processor)
Smallpt is a C++ global illumination renderer written in less than 100 lines of code. Global illumination is done via unbiased Monte Carlo path tracing and there is multi-threading support via the OpenMP library.  

- Embassy time: 6 minutes

### sqlite (Disk)
This is a simple benchmark of SQLite. At present this test profile just measures the time to perform a pre-defined number of insertions on an indexed database.

- Embassy Time: 1 minute

### pts/iozone (Disk)
(disabled by default)  
The IOzone benchmark tests the hard disk drive / file-system performance.

- Embassy Time: 4 Hours
