SCALE     = ../../..
SCALE_INC = -I$(SCALE)/dc_utils \
            -I$(SCALE)/gtool    \
            -I$(SCALE)/include
SCALE_LIB = -L$(SCALE)/lib -lscale -lgtool -ldcutils
SCALE_LES_OBJDIR = $(SCALE)/scale-les/src/.libs

include $(SCALE)/sysdep/Makedef.$(SCALE_SYS)
include $(SCALE)/Mkinclude

#NETCDF_INC = -I/opt/aics/netcdf/k-serial-noszip/include
#NETCDF_LIB = -L/opt/aics/netcdf/k-serial-noszip/lib-static -lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lz -lm
NETCDF_INC = $(NETCDF_INCLUDE)
NETCDF_LIB = $(NETCDF_LIBS)

#LAPACK_LIB = -SSL2BLAMP
LAPACK_LIB = -L/usr/lib/lapack -llapack -L/usr/lib/libblas -lblas

BUFR_LIB  =

#######

#SFC       = frtpx
#FC        = mpifrtpx

FOPTS_SCALE = $(FFLAGS) -std=gnu -ffree-line-length-none
#FOPTS_SCALE = -cpp -ffree-line-length-none

#FOPTS     = -Kfast,ocl,openmp,noeval -V -Qa,d,i,p,t,x -Koptmsg=2 \
#            -x-    \
#            -Ksimd \
#            -Kauto,threadsafe
#FOPTS     = $(FOPTS_SCALE) \
#            -Knoparallel,noeval,nopreex \
#            -Kopenmp
FOPTS     = $(FOPTS_SCALE)

FMCMODEL  =
FBYTESWAP = 
FFREE     = -Free
FFIXED    = -Fixed
