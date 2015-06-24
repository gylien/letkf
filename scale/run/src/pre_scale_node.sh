#!/bin/bash
#===============================================================================
#
#  Script to prepare the directory of scale run; for each node.
#  June      2015  created  Guo-Yuan Lien
#
#===============================================================================

. config.main

if (($# < 8)); then
  cat >&2 << EOF

[pre_scale_node.sh] 

Usage: $0 MYRANK MEM_NODES MEM_NP TMPDIR EXECDIR DATADIR MEMBER_RUN MEMBER_ITER

  MYRANK     My rank number (not used)
  MEM_NODES  Number of nodes for a member
  MEM_NP     Number of processes per member
  TMPDIR     Temporary directory to run the model
  EXECDIR    Directory of SCALE executable files
  DATADIR    Directory of SCALE data files
  MEMBER_RUN
  MEMBER_ITER

EOF
  exit 1
fi

MYRANK="$1"; shift
MEM_NODES="$1"; shift
MEM_NP="$1"; shift
TMPDIR="$1"; shift
EXECDIR="$1"; shift
DATADIR="$1"; shift
MEMBER_RUN="$1"; shift
MEMBER_ITER="$1"

#===============================================================================

cat $TMPDAT/conf/config.nml.ensmodel | \
    sed -e "s/\[MEMBER\]/ MEMBER = $MEMBER,/" \
        -e "s/\[MEMBER_RUN\]/ MEMBER_RUN = $MEMBER_RUN,/" \
        -e "s/\[MEMBER_ITER\]/ MEMBER_ITER = $MEMBER_ITER,/" \
        -e "s/\[NNODES\]/ NNODES = $NNODES,/" \
        -e "s/\[PPN\]/ PPN = $PPN,/" \
        -e "s/\[MEM_NODES\]/ MEM_NODES = $MEM_NODES,/" \
        -e "s/\[MEM_NP\]/ MEM_NP = $MEM_NP,/" \
    > $TMPDIR/scale-les_ens.conf

#===============================================================================

exit 0
