MODULE letkf_tools
!=======================================================================
!
! [PURPOSE:] Module for LETKF with ROMS
!
! [HISTORY:]
!   01/26/2009 Takemasa Miyoshi  created
!   02/03/2009 Takemasa Miyoshi  modified for ROMS
!
!=======================================================================
!$USE OMP_LIB
  USE common
  USE common_mpi
  USE common_roms
  USE common_mpi_roms
  USE common_letkf
  USE letkf_obs

  IMPLICIT NONE

  PRIVATE
  PUBLIC ::  das_letkf

  INTEGER,SAVE :: nobstotal

  REAL(r_size),PARAMETER :: cov_infl_mul = -1.00d0 !multiplicative inflation
! > 0: globally constant covariance inflation
! < 0: 3D inflation values input from a GPV file "infl_mul.grd"
  REAL(r_size),PARAMETER :: sp_infl_add = 0.d0 !additive inflation

CONTAINS
!-----------------------------------------------------------------------
! Data Assimilation
!-----------------------------------------------------------------------
SUBROUTINE das_letkf(gues3d,gues2d,anal3d,anal2d)
  IMPLICIT NONE
  CHARACTER(11) :: inflfile='infl_mul.nc'
  REAL(r_size),INTENT(INOUT) :: gues3d(nij1,nlev,nbv,nv3d) ! background ensemble
  REAL(r_size),INTENT(INOUT) :: gues2d(nij1,nbv,nv2d)      !  output: destroyed
  REAL(r_size),INTENT(OUT) :: anal3d(nij1,nlev,nbv,nv3d) ! analysis ensemble
  REAL(r_size),INTENT(OUT) :: anal2d(nij1,nbv,nv2d)
  REAL(r_size),ALLOCATABLE :: mean3d(:,:,:)
  REAL(r_size),ALLOCATABLE :: mean2d(:,:)
  REAL(r_size),ALLOCATABLE :: hdxf(:,:)
  REAL(r_size),ALLOCATABLE :: rdiag(:)
  REAL(r_size),ALLOCATABLE :: rloc(:)
  REAL(r_size),ALLOCATABLE :: dep(:)
  REAL(r_size),ALLOCATABLE :: work3d(:,:,:)
  REAL(r_size),ALLOCATABLE :: work2d(:,:)
  REAL(r_sngl),ALLOCATABLE :: work3dg(:,:,:,:)
  REAL(r_sngl),ALLOCATABLE :: work2dg(:,:,:)
  REAL(r_size),ALLOCATABLE :: depth(:,:)
  REAL(r_size) :: parm
  REAL(r_size) :: trans(nbv,nbv)
  INTEGER :: ij,ilev,n,m,i,j,k,nobsl,ierr
  LOGICAL :: ex

  WRITE(6,'(A)') 'Hello from das_letkf'
  nobstotal = nobs
  WRITE(6,'(A,I8)') 'Target observation numbers : NOBS=',nobs
  !
  ! In case of no obs
  !
  IF(nobstotal == 0) THEN
    WRITE(6,'(A)') 'No observation assimilated'
    anal3d = gues3d
    anal2d = gues2d
    RETURN
  END IF
  !
  ! FCST PERTURBATIONS
  !
  ALLOCATE(mean3d(nij1,nlev,nv3d))
  ALLOCATE(mean2d(nij1,nv2d))
  CALL ensmean_grd(nbv,nij1,gues3d,gues2d,mean3d,mean2d)
  DO n=1,nv3d
    DO m=1,nbv
      DO k=1,nlev
        DO i=1,nij1
          gues3d(i,k,m,n) = gues3d(i,k,m,n) - mean3d(i,k,n)
        END DO
      END DO
    END DO
  END DO
  DO n=1,nv2d
    DO m=1,nbv
      DO i=1,nij1
        gues2d(i,m,n) = gues2d(i,m,n) - mean2d(i,n)
      END DO
    END DO
  END DO
  !
  ! depth
  !
  ALLOCATE(depth(nij1,nlev))
  DO i=1,nij1
    CALL calc_depth(mean2d(i,iv2d_z),phi1(i),depth(i,:))
  END DO
  !
  ! multiplicative inflation
  !
  IF(cov_infl_mul > 0.0d0) THEN ! fixed multiplicative inflation parameter
    ALLOCATE( work3d(nij1,nlev,nv3d) )
    ALLOCATE( work2d(nij1,nv2d) )
    work3d = cov_infl_mul
    work2d = cov_infl_mul
  END IF
  IF(cov_infl_mul <= 0.0d0) THEN ! 3D parameter values are read-in
    ALLOCATE( work3dg(nlon,nlat,nlev,nv3d) )
    ALLOCATE( work2dg(nlon,nlat,nv2d) )
    ALLOCATE( work3d(nij1,nlev,nv3d) )
    ALLOCATE( work2d(nij1,nv2d) )
    INQUIRE(FILE=inflfile,EXIST=ex)
    IF(ex) THEN
      IF(myrank == 0) THEN
        WRITE(6,'(A,I3.3,2A)') 'MYRANK ',myrank,' is reading.. ',inflfile
        CALL read_grd4(inflfile,work3dg,work2dg)
        !work3dg =1.0
        !work2dg =1.0
        !CALL write_grd4(inflfile,work3dg,work2dg)
        !WRITE(6,'(2A)') '!!ERROR: stop',inflfile
        !STOP
      END IF
      CALL scatter_grd_mpi(0,work3dg,work2dg,work3d,work2d)
    ELSE
      WRITE(6,'(2A)') '!!ERROR: no such file exist: ',inflfile
      STOP
      work3d = -1.0d0 * cov_infl_mul
    END IF
  END IF
  !
  ! MAIN ASSIMILATION LOOP
  !
  ALLOCATE( hdxf(1:nobstotal,1:nbv),rdiag(1:nobstotal),rloc(1:nobstotal),dep(1:nobstotal) )
  DO ilev=1,nlev
    WRITE(6,'(A,I3)') 'ilev = ',ilev
    DO ij=1,nij1
      CALL obs_local(ij,ilev,depth(ij,ilev),hdxf,rdiag,rloc,dep,nobsl)
      parm = work3d(ij,ilev,iv3d_t)
      CALL letkf_core(nbv,nobstotal,nobsl,hdxf,rdiag,rloc,dep,parm,trans)
      DO n=1,nv3d
        DO m=1,nbv
          anal3d(ij,ilev,m,n) = mean3d(ij,ilev,n)
          DO k=1,nbv
            anal3d(ij,ilev,m,n) = anal3d(ij,ilev,m,n) &
              & + gues3d(ij,ilev,k,n) * trans(k,m)
          END DO
        END DO
      END DO
      IF(ilev == nlev) THEN
        DO n=1,nv2d
          IF(n==iv2d_ubar .OR. n==iv2d_vbar .OR. n==iv2d_hbl) THEN
            DO m=1,nbv
              anal2d(ij,m,n)  = mean2d(ij,n) + gues2d(ij,m,n)
            END DO
          ELSE
            DO m=1,nbv
              anal2d(ij,m,n)  = mean2d(ij,n)
              DO k=1,nbv
                anal2d(ij,m,n) = anal2d(ij,m,n) + gues2d(ij,k,n) * trans(k,m)
              END DO
            END DO
          END IF
        END DO
      END IF
      IF(cov_infl_mul < 0.0d0) THEN
        work3d(ij,ilev,:) = parm
        IF(ilev == nlev) work2d(ij,:) = parm
      END IF
    END DO
  END DO
  DEALLOCATE(hdxf,rdiag,rloc,dep)
  IF(cov_infl_mul < 0.0d0) THEN
    CALL gather_grd_mpi(0,work3d,work2d,work3dg,work2dg)
    IF(myrank == 0) THEN
      WRITE(6,'(A,I3.3,2A)') 'MYRANK ',myrank,' is writing.. ',inflfile
      CALL write_grd4(inflfile,work3dg,work2dg)
    END IF
    DEALLOCATE(work3dg,work2dg,work3d,work2d)
  END IF
  !
  ! Additive inflation
  !
  IF(sp_infl_add > 0.0d0) THEN
    CALL read_ens_mpi('addi',nbv,gues3d,gues2d)
    ALLOCATE( work3d(nij1,nlev,nv3d) )
    ALLOCATE( work2d(nij1,nv2d) )
    CALL ensmean_grd(nbv,nij1,gues3d,gues2d,work3d,work2d)
    DO n=1,nv3d
      DO m=1,nbv
        DO k=1,nlev
          DO i=1,nij1
            gues3d(i,k,m,n) = gues3d(i,k,m,n) - work3d(i,k,n)
          END DO
        END DO
      END DO
    END DO
    DO n=1,nv2d
      DO m=1,nbv
        DO i=1,nij1
          gues2d(i,m,n) = gues2d(i,m,n) - work2d(i,n)
        END DO
      END DO
    END DO

    DEALLOCATE(work3d,work2d)
    WRITE(6,'(A)') '===== Additive covariance inflation ====='
    WRITE(6,'(A,F10.4)') '  parameter:',sp_infl_add
    WRITE(6,'(A)') '========================================='
!    parm = 0.7d0
!    DO ilev=1,nlev
!      parm_infl_damp(ilev) = 1.0d0 + parm &
!        & + parm * REAL(1-ilev,r_size)/REAL(nlev_dampinfl,r_size)
!      parm_infl_damp(ilev) = MAX(parm_infl_damp(ilev),1.0d0)
!    END DO
    DO n=1,nv3d
      DO m=1,nbv
        DO ilev=1,nlev
          DO ij=1,nij1
            anal3d(ij,ilev,m,n) = anal3d(ij,ilev,m,n) &
              & + gues3d(ij,ilev,m,n) * sp_infl_add
          END DO
        END DO
      END DO
    END DO
    DO n=1,nv2d
      DO m=1,nbv
        DO ij=1,nij1
          anal2d(ij,m,n) = anal2d(ij,m,n) + gues2d(ij,m,n) * sp_infl_add
        END DO
      END DO
    END DO
  END IF
  !
  ! Force non-negative s
  !
  DO m=1,nbv
    DO ilev=1,nlev
      DO ij=1,nij1
        anal3d(ij,ilev,m,iv3d_s) = MAX(anal3d(ij,ilev,m,iv3d_s),0.0d0)
      END DO
    END DO
  END DO

  DEALLOCATE(mean3d,mean2d)
  RETURN
END SUBROUTINE das_letkf
!-----------------------------------------------------------------------
! Project global observations to local
!     (hdxf_g,dep_g,rdiag_g) -> (hdxf,dep,rdiag)
!-----------------------------------------------------------------------
SUBROUTINE obs_local(ij,ilev,depth,hdxf,rdiag,rloc,dep,nobsl)
  IMPLICIT NONE
  INTEGER,INTENT(IN) :: ij,ilev
  REAL(r_size),INTENT(IN) :: depth
  REAL(r_size),INTENT(OUT) :: hdxf(nobstotal,nbv)
  REAL(r_size),INTENT(OUT) :: rdiag(nobstotal)
  REAL(r_size),INTENT(OUT) :: rloc(nobstotal)
  REAL(r_size),INTENT(OUT) :: dep(nobstotal)
  INTEGER,INTENT(OUT) :: nobsl
  REAL(r_size) :: minlon,maxlon,minlat,maxlat,dist,dlev
  INTEGER,ALLOCATABLE:: nobs_use(:)
  INTEGER :: imin,imax,jmin,jmax,im,ichan
  INTEGER :: n,nn
!
! INITIALIZE
!
  IF( nobs > 0 ) THEN
    ALLOCATE(nobs_use(nobs))
  END IF
!
! data search
!
  imin = MAX(NINT(ri1(ij) - dist_zero),1)
  imax = MIN(NINT(ri1(ij) + dist_zero),nlon)
  jmin = MAX(NINT(rj1(ij) - dist_zero),1)
  jmax = MIN(NINT(rj1(ij) + dist_zero),nlat)

  nn = 1
  IF( nobs > 0 ) CALL obs_local_sub(imin,imax,jmin,jmax,nn,nobs_use)
  nn = nn-1
  IF(nn < 1) THEN
    nobsl = 0
    RETURN
  END IF
!
! CONVENTIONAL
!
  nobsl = 0
  IF(nn > 0) THEN
    DO n=1,nn
      IF(NINT(obselm(nobs_use(n))) == id_z_obs .AND. ilev < nlev) THEN
        dlev = ABS(depth)
      ELSE IF(NINT(obselm(nobs_use(n))) /= id_z_obs) THEN
        dlev = ABS(obslev(nobs_use(n)) - depth)
      ELSE
        dlev = 0.0d0
      END IF
      IF(dlev > dist_zerov) CYCLE

      dist = SQRT((obsi(nobs_use(n))-ri1(ij))**2 &
        & + (obsj(nobs_use(n))-rj1(ij))**2)
      IF(dist > dist_zero ) CYCLE

      nobsl = nobsl + 1
      hdxf(nobsl,:) = obshdxf(nobs_use(n),:)
      dep(nobsl)    = obsdep(nobs_use(n))
      !
      ! Observational localization
      !
      rdiag(nobsl) = obserr(nobs_use(n))**2
      rloc(nobsl) = EXP(-0.5d0 * ((dist/sigma_obs)**2 + (dlev/sigma_obsv)**2))
    END DO
  END IF
!
! DEBUG
! IF( ILEV == 1 .AND. ILON == 1 ) &
! & WRITE(6,*) 'ILEV,ILON,ILAT,NN,TVNN,NOBSL=',ilev,ij,nn,tvnn,nobsl
!
  IF( nobsl > nobstotal ) THEN
    WRITE(6,'(A,I5,A,I5)') 'FATAL ERROR, NOBSL=',nobsl,' > NOBSTOTAL=',nobstotal
    WRITE(6,*) 'IJ,NN=',ij,nn
    STOP 99
  END IF
!
  IF( nobs > 0 ) THEN
    DEALLOCATE(nobs_use)
  END IF
!
  RETURN
END SUBROUTINE obs_local

SUBROUTINE obs_local_sub(imin,imax,jmin,jmax,nn,nobs_use)
  INTEGER,INTENT(IN) :: imin,imax,jmin,jmax
  INTEGER,INTENT(INOUT) :: nn, nobs_use(nobs)
  INTEGER :: j,n,ib,ie,ip

  DO j=jmin,jmax
    IF(imin > 1) THEN
      ib = nobsgrd(imin-1,j)+1
    ELSE
      IF(j > 1) THEN
        ib = nobsgrd(nlon,j-1)+1
      ELSE
        ib = 1
      END IF
    END IF
    ie = nobsgrd(imax,j)
    n = ie - ib + 1
    IF(n == 0) CYCLE
    DO ip=ib,ie
      IF(nn > nobs) THEN
        WRITE(6,*) 'FATALERROR, NN > NOBS', NN, NOBS
      END IF
      nobs_use(nn) = ip
      nn = nn + 1
    END DO
  END DO

  RETURN
END SUBROUTINE obs_local_sub

END MODULE letkf_tools
