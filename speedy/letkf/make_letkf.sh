#!/bin/sh
set -ex
PGM=letkf020.m01
F90=mpif90
OMP=
#F90OPT='-byteswapio -tp p7-64 -fast -O3'
F90OPT='-convert big_endian -O3 -xHost -assume byterecl'
#INLINE="-Minline"
INLINE=
BLAS=1 #0: no blas 1: using blas

sh ulnkcommon.sh
sh lnkcommon.sh
rm -f *.mod
rm -f *.o

cat netlib.f > netlib2.f
if test $BLAS -eq 1
then
#LBLAS="-lblas"
LBLAS="-mkl"
else
cat netlibblas.f >> netlib2.f
LBLAS=""
fi
$F90 $OMP $F90OPT $INLINE -c SFMT.f90
$F90 $OMP $F90OPT $INLINE -c common.f90
$F90 $OMP $F90OPT -c common_mpi.f90
$F90 $OMP $F90OPT $INLINE -c common_mtx.f90
$F90 $OMP $F90OPT $INLINE -c netlib2.f
$F90 $OMP $F90OPT -c common_letkf.f90
$F90 $OMP $F90OPT $INLINE -c common_speedy.f90
$F90 $OMP $F90OPT -c common_obs_speedy.f90
$F90 $OMP $F90OPT -c common_mpi_speedy.f90
$F90 $OMP $F90OPT -c letkf_obs.f90
$F90 $OMP $F90OPT -c letkf_tools.f90
$F90 $OMP $F90OPT -c letkf.f90
$F90 $OMP $F90OPT -o ${PGM} *.o $LBLAS

rm -f *.mod
rm -f *.o
rm -f netlib2.f
sh ulnkcommon.sh

echo "NORMAL END"
