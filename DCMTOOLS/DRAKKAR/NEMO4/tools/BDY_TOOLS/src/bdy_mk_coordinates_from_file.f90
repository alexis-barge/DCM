PROGRAM bdy_mk_coordinates
  !!======================================================================
  !!                     ***  PROGRAM  bdy_mk_coordinates  ***
  !!=====================================================================
  !!  ** Purpose : Read a rim file (build with BMGTOOLS) where rims are
  !!               given the values 100 200 etc for rim 0 1 ... and produce
  !!               a BDY coordinates files ( nbit, nbjt, nbrt)
  !!
  !!  ** Method  : scan the input file in a clever way ...
  !!
  !! History :  1.0  : 08/2019  : J.M. Molines : 
  !!----------------------------------------------------------------------
  !!----------------------------------------------------------------------
  !!   routines      : description
  !!----------------------------------------------------------------------
  USE netcdf
  !!----------------------------------------------------------------------
  !! $Id$
  !! Copyright (c) 2019, J.-M. Molines
  !! Software governed by the CeCILL licence (Licence/CDFTOOLSCeCILL.txt)
  !!----------------------------------------------------------------------
  IMPLICIT NONE
  INTEGER(KIND=4)               :: ji,jj,jr
  INTEGER(KIND=4)               :: narg, iargc, ijarg
  INTEGER(KIND=4)               :: npiglo, npjglo
  INTEGER(KIND=4)               :: iioff, ijoff
  INTEGER(KIND=4)               :: nrim,  irim
  INTEGER(KIND=4)               :: nxt, ii
  INTEGER(KIND=4)               :: ncid, id, ierr
  INTEGER(KIND=4)               :: idxt,idxu,idxv, idy
  INTEGER(KIND=4)               :: idit,idjt,idrt
  INTEGER(KIND=4)               :: idiu,idju,idru
  INTEGER(KIND=4)               :: idiv,idjv,idrv

  INTEGER(KIND=4), DIMENSION(:), ALLOCATABLE :: nbit, nbjt, nbrt
  INTEGER(KIND=4), DIMENSION(:), ALLOCATABLE :: nbiu, nbju, nbru
  INTEGER(KIND=4), DIMENSION(:), ALLOCATABLE :: nbiv, nbjv, nbrv

  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: v2d,zwk

  CHARACTER(LEN=255) :: cf_rim 
  CHARACTER(LEN=255) :: cv_rim ="Bathymetry"  ! BMGTOOLS does it !
  CHARACTER(LEN=255) :: c_dimx ="x"         
  CHARACTER(LEN=255) :: c_dimy ="y"        
  CHARACTER(LEN=255) :: c_dimt ="time_counter"           
  CHARACTER(LEN=255) :: c_dimz ="z"          
  CHARACTER(LEN=80)  :: cldum
  CHARACTER(LEN=80)  :: cbdy_typ='none'
  CHARACTER(LEN=255) :: cf_out='bdy_coordinates.nc'

  CHARACTER(LEN=20) :: cn_votemper='votemper', cn_vosaline='vosaline', cn_sossheig='sossheig'
  CHARACTER(LEN=20) :: cn_vozocrtx='vozocrtx', cn_vomecrty='vomecrty'
  CHARACTER(LEN=20) :: cn_ileadfra='ileadfra', cn_iicethic='iicethic'

  LOGICAL            :: ll_data=.FALSE.


  !!---------------------------------------------------------------------
  narg=iargc()
  iioff=1
  ijoff=1
  IF ( narg == 0 ) THEN
     PRINT *,'   '
     PRINT *,'  usage : bdy_mk_coordinates_from_file -f RIM-file -t BDY-type'
     PRINT *,'          [-o BDY-coordinates-file] [-offset I-offset J-offset]'
     PRINT *,'          [-data DTASET-name]'
     PRINT *,'   '
     PRINT *,'  PURPOSE :'
     PRINT *,'     Build bdy coordinates file from rim file. At this stage this program'
     PRINT *,'     assumes that boundary are recti-linear (however, oblique). Rim file is'
     PRINT *,'     a hand-prepared files (BMGTOOLS) using tmaskutil as a basis and where'
     PRINT *,'     rim number is indicated for T points, starting with 100 (rim-0) to '
     PRINT *,'     100*(rimwidth) + 100.' 
     PRINT *,'   '
     PRINT *,'  ARGUMENTS :'
     PRINT *,'    -f RIM-file : gives the name of the original rim file'
     PRINT *,'    -t BDY-type : One of N S E W. Although the boundary geometry is not'
     PRINT *,'        strictly N S E or W, as far as we are dealing with strait lines'
     PRINT *,'        we can always figure out one of those type for the BDY.'
     PRINT *,'   '
     PRINT *,'  OPTIONS :'
     PRINT *,'    -o BDY-coordinates-file : name of output file instead of default '
     PRINT *,'        name : ',TRIM(cf_out)
     PRINT *,'    -offset I-offset J-offset : If specified, the resulting nbix, nbjx '
     PRINT *,'        from this program will be offset with the given (I,J) pait. This is '
     PRINT *,'        usefull for building the final configuration bdy coordinates, as in'
     PRINT *,'        general work is done locally on a smaller domain around the bdy.'
     PRINT *,'        Iglobal = Ilocal + I-offset -1'
     PRINT *,'        Jglobal = Jlocal + J-offset -1'
     PRINT *,'    -data DTASET-name : This is the base name of a pre-computed data set '
     PRINT *,'        corresponding to the working boundary, associated with the rim-file.'
     PRINT *,'        The program will look for <VAR>_DTASET-name.nc files with <VAR> in :'
     PRINT *,'        votemper, vosaline,vozocrtx,vomecrty, sossheig,ileadfra,iicethic.'
     PRINT *,'        If a file is not found, assumes that this variable is not required'
     PRINT *,'        at the boundaries.'
     PRINT *,'   '
     PRINT *,'  REQUIRED FILES :'
     PRINT *,'    none'
     PRINT *,'   '
     PRINT *,'  OUTPUT : '
     PRINT *,'    netcdf file : ',TRIM(cf_out)
     PRINT *,'      variables :  nbit,nbjt,nbr and equivalent for u and '
     PRINT *,'   '
     PRINT *,'  SEE ALSO :'
     PRINT *,'     bdy_mk_coordinate'
     PRINT *,'      '
     STOP
  ENDIF

  ijarg = 1 
  DO WHILE ( ijarg <= narg )
     CALL getarg(ijarg, cldum ) ; ijarg=ijarg+1
     SELECT CASE ( cldum )
     CASE ( '-f'     ) ; CALL getarg(ijarg, cf_rim ) ; ijarg=ijarg+1
     CASE ( '-t'     ) ; CALL getarg(ijarg,cbdy_typ) ; ijarg=ijarg+1
        ! options
     CASE ( '-o'     ) ; CALL getarg(ijarg,cf_out  ) ; ijarg=ijarg+1
     CASE ( '-offset') ; CALL getarg(ijarg,cldum   ) ; ijarg=ijarg+1 ; READ(cldum,*) iioff
        ;              ; CALL getarg(ijarg,cldum   ) ; ijarg=ijarg+1 ; READ(cldum,*) ijoff
     CASE ( '-data  ') ; ll_data=.TRUE.
     CASE DEFAULT      ; PRINT *, ' ERROR : ', TRIM(cldum),' : unknown option.'; STOP 1

     END SELECT
  ENDDO
  IF ( cbdy_typ == 'none' ) THEN
     PRINT *,'  +++ E R R O R: You must specify a bdy-type with option -t '
     STOP 999
  ENDIF

  ! read rim file
  ierr = NF90_OPEN(cf_rim,NF90_NOWRITE,ncid)
  ierr = NF90_INQ_DIMID(ncid,c_dimx,id)  ; ierr = NF90_INQUIRE_DIMENSION(ncid,id,len=npiglo)
  ierr = NF90_INQ_DIMID(ncid,c_dimy,id)  ; ierr = NF90_INQUIRE_DIMENSION(ncid,id,len=npjglo)

  ALLOCATE (v2d(npiglo,npjglo), zwk(npiglo,npjglo) )
  ierr = NF90_INQ_VARID(ncid,cv_rim,id)  ! BMGTOOLS impose Bathymetry ...
  ierr = NF90_GET_VAR(ncid,id,v2d )
  ierr = NF90_CLOSE(ncid)

  zwk=0.
  WHERE( v2d >= 100 ) zwk = 1.
  nrim=( MAXVAL(v2d) - 100 )/100 + 1

  nxt = SUM(zwk)
  ALLOCATE (nbit(nxt), nbjt(nxt), nbrt(nxt) )
  ALLOCATE (nbiu(nxt), nbju(nxt), nbru(nxt) )
  ALLOCATE (nbiv(nxt), nbjv(nxt), nbrv(nxt) )
  nbit=-9999
  nbjt=-9999
  nbrt=-9999


  PRINT *, ' Number of rims : ', nrim
  PRINT *, '           nXt  : ', nxt

  ii=0
  DO jr=1,nrim
     DO ji=1,npiglo
        DO jj=1,npjglo
           IF ( v2d(ji,jj) < 100 ) CYCLE
           irim = (v2d(ji,jj) - 100 )/100
           IF ( irim == jr-1  ) THEN
              ii = ii + 1
              nbit(ii) = ji
              nbjt(ii) = jj
              nbrt(ii) = irim
           ENDIF
        ENDDO
     ENDDO
  ENDDO

  ! now deduce the u, v values (
  SELECT CASE ( cbdy_typ )
  CASE ('N')
     nbiu=nbit
     nbju=nbjt
     nbru=nbrt
     nbiv=nbit
     nbjv=nbjt-1
     nbrv=nbrt
  CASE ('S','W')
     nbiu=nbit
     nbju=nbjt
     nbru=nbrt
     nbiv=nbit
     nbjv=nbjt
     nbrv=nbrt
  CASE ('E')
     nbiu=nbit-1
     nbju=nbjt
     nbru=nbrt
     nbiv=nbit
     nbjv=nbjt
     nbrv=nbrt
  END SELECT

  DEALLOCATE( v2d, zwk)

  IF (ll_data) THEN
     CALL CreateData(cn_votemper,'T')
     CALL CreateData(cn_vosaline,'T')
     CALL CreateData(cn_sossheig,'T')
     CALL CreateData(cn_vozocrtx,'U')
     CALL CreateData(cn_vomecrty,'V')
     CALL CreateData(cn_ileadfra,'T')
     CALL CreateData(cn_iicethic,'T')

  ENDIF

  ! write output file (bdy_coordinates file)
  ierr = NF90_CREATE( cf_out, NF90_NETCDF4,ncid)
  ierr = NF90_DEF_DIM(ncid,'yb',1, idy)
  ierr = NF90_DEF_DIM(ncid,'xbT',nxt, idxt)
  ierr = NF90_DEF_DIM(ncid,'xbU',nxt, idxu)
  ierr = NF90_DEF_DIM(ncid,'xbV',nxt, idxv)

  ierr = NF90_DEF_VAR(ncid,'nbit',NF90_INT,(/idxt,idy/),idit)
  ierr = NF90_DEF_VAR(ncid,'nbjt',NF90_INT,(/idxt,idy/),idjt)
  ierr = NF90_DEF_VAR(ncid,'nbrt',NF90_INT,(/idxt,idy/),idrt)

  ierr = NF90_DEF_VAR(ncid,'nbiu',NF90_INT,(/idxu,idy/),idiu)
  ierr = NF90_DEF_VAR(ncid,'nbju',NF90_INT,(/idxu,idy/),idju)
  ierr = NF90_DEF_VAR(ncid,'nbru',NF90_INT,(/idxu,idy/),idru)

  ierr = NF90_DEF_VAR(ncid,'nbiv',NF90_INT,(/idxu,idy/),idiv)
  ierr = NF90_DEF_VAR(ncid,'nbjv',NF90_INT,(/idxu,idy/),idjv)
  ierr = NF90_DEF_VAR(ncid,'nbrv',NF90_INT,(/idxu,idy/),idrv)

  ierr = NF90_PUT_ATT(ncid,NF90_GLOBAL,'rimwidth',nrim-1)

  ierr = NF90_ENDDEF(ncid)
  ! apply offset
  nbit=nbit+ iioff-1 ; nbiu=nbiu+iioff-1 ;  nbiv=nbiv+iioff-1
  nbjt=nbjt+ ijoff-1 ; nbju=nbju+iioff-1 ;  nbjv=nbjv+ijoff-1

  ierr = NF90_PUT_VAR( ncid,idit,nbit)
  ierr = NF90_PUT_VAR( ncid,idjt,nbjt)
  ierr = NF90_PUT_VAR( ncid,idrt,nbrt)

  ierr = NF90_PUT_VAR( ncid,idiu,nbiu)
  ierr = NF90_PUT_VAR( ncid,idju,nbju)
  ierr = NF90_PUT_VAR( ncid,idru,nbru)

  ierr = NF90_PUT_VAR( ncid,idiv,nbiv)
  ierr = NF90_PUT_VAR( ncid,idjv,nbjv)
  ierr = NF90_PUT_VAR( ncid,idrv,nbrv)

  ierr = NF90_CLOSE(ncid)

CONTAINS

  SUBROUTINE CreateData ( cd_var, cd_typ)
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE CreateData  ***
    !!
    !! ** Purpose :  Create the bdydata netcdffile corresponding to cd_var
    !!               according to its position on the C-grid 
    !!
    !! ** Method  :  Read or use pre computed nbix, nbjx bdy points position
    !!               and extract the relevant variables from the data files,
    !!               assuming they already exists on a bubset of the model grid. 
    !!
    !!----------------------------------------------------------------------
    ! Arguments
    CHARACTER(LEN=*), INTENT(in) :: cd_var
    CHARACTER(LEN=1), INTENT(in) :: cd_typ
    ! local
    INTEGER(KIND=4) :: jf, jt, jx, jk  ! dummy loop index
    INTEGER(KIND=4) :: infile,  ierr, incid, id, idim
    INTEGER(KIND=4) :: incout, idout
    INTEGER(KIND=4) :: ipiglo, ipjglo, ipt, ipkglo, ii, ij
    INTEGER(KIND=4), DIMENSION(nxt) :: nbi, nbj

    REAL(KIND=4), DIMENSION(:,:),   ALLOCATABLE :: zdata
    REAL(KIND=4), DIMENSION(:)    , ALLOCATABLE :: zbdydata

    CHARACTER(LEN=255), DIMENSION(:), ALLOCATABLE :: cl_list
    CHARACTER(LEN=255)                            :: clf_in
    !!----------------------------------------------------------------------
    CALL GetList( cd_var, cl_list, infile)    
    DO jf= 1, infile
       clf_in=TRIM(cl_list(jf))
       PRINT *, clf_in
       ierr=NF90_OPEN(clf_in,NF90_NOWRITE,incid)
       ierr=NF90_INQUIRE(incid,nDimensions=idim)
       ierr=NF90_INQ_DIMID(incid,c_dimx,id) ; ierr=NF90_INQUIRE_DIMENSION(incid,id,len=ipiglo)
       ierr=NF90_INQ_DIMID(incid,c_dimy,id) ; ierr=NF90_INQUIRE_DIMENSION(incid,id,len=ipjglo)
       ierr=NF90_INQ_DIMID(incid,c_dimt,id) ; ierr=NF90_INQUIRE_DIMENSION(incid,id,len=ipt)
       ipkglo=1
       IF ( idim ==4 )  THEN
          ierr=NF90_INQ_DIMID(incid,c_dimz,id) ; ierr=NF90_INQUIRE_DIMENSION(incid,id,len=ipkglo)
       ENDIF
       ALLOCATE(zbdydata(nxt) )
       IF ( ipiglo /= npiglo .OR. ipjglo /= npjglo) THEN
          PRINT *, ' inconsistent domain size between rim file and data file '
          STOP 'ERROR 1'
       ENDIF
       ALLOCATE (zdata(npiglo,npjglo) )
       ierr = NF90_INQ_DIMID(incid,cd_var,id)
       CALL CreateOutput(clf_in,cd_var,ipkglo, incout, idout)
       DO jt=1,ipt
          DO jk=1, ipkglo
             ierr = NF90_GET_VAR(incid,id,zdata,start=(/1,1,jk,jt/), count=(/npiglo,npjglo,1,1/) )
             PRINT *,NF90_STRERROR(ierr)
             SELECT CASE ( cd_typ)
             CASE ('T') ; nbi=nbit ; nbj=nbjt
             CASE ('U') ; nbi=nbiu ; nbj=nbju
             CASE ('V') ; nbi=nbiv ; nbj=nbjv
             END SELECT
             DO jx=1,nxt
                ii=nbi(jx)
                ij=nbj(jx)
                zbdydata(jx) = zdata(ii,ij)
             ENDDO
             ierr = NF90_PUT_VAR(incout,idout,zbdydata(:), start=(/1,jk,jt/), count=(/nxt,1,1/) )
          ENDDO
       ENDDO
       ierr = NF90_CLOSE(incout)

       DEALLOCATE ( zdata, zbdydata )
       ierr = NF90_CLOSE(incid)
    ENDDO
  END SUBROUTINE CreateData

  SUBROUTINE CreateOutput( cd_file, cd_var, kpkglo, kncout, kidout)
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE CreateOutput  ***
    !!
    !! ** Purpose :   Create bdy_data netcdf output file
    !!
    !! ** Method  :   Infer name from data file, create variable, according to
    !!                its 2D/3D character and return ncout and idout
    !!
    !!----------------------------------------------------------------------
    ! Arguments
    CHARACTER(LEN=*), INTENT(in) :: cd_file  ! name of the data files used for xtrac
    CHARACTER(LEN=*), INTENT(in) :: cd_var   ! name of the  variable to process

    INTEGER(KIND=4), INTENT(in )  :: kpkglo  ! number of dimensions for cd_var
    INTEGER(KIND=4), INTENT(out)  :: kncout  ! netcdf id of the output file
    INTEGER(KIND=4), INTENT(out)  :: kidout  ! varid of the output variables
    ! Local 
    INTEGER(KIND=4)    :: ierr
    INTEGER(KIND=4)    :: idx, idy,idz,idt
    CHARACTER(LEN=255) :: cl_file
    !!----------------------------------------------------------------------
    cl_file='bdydta_'//TRIM(cd_file)
    ierr = NF90_CREATE(cl_file,NF90_NETCDF4,kncout)

    ierr = NF90_DEF_DIM(kncout,'yb',1  ,idy)
    ierr = NF90_DEF_DIM(kncout,'xt',nxt,idx)
    ierr = NF90_DEF_DIM(kncout,'time_counter',NF90_UNLIMITED,idt)
    IF ( kpkglo /= 1  ) THEN
       ierr = NF90_DEF_DIM(kncout,'z',kpkglo,idz)
       ierr = NF90_DEF_VAR(kncout,cd_var,NF90_FLOAT,(/idx,idy,idz,idt/), kidout )
    ELSE
       ierr = NF90_DEF_VAR(kncout,cd_var,NF90_FLOAT,(/idx,idy,idt/), kidout )
    ENDIF
    ierr = NF90_ENDDEF(kncout)

  END SUBROUTINE CreateOutput


  SUBROUTINE GetList ( cd_var, cd_list, kfile )
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE GetList  ***
    !!
    !! ** Purpose :  Allocate and fill in cd_list(:) with the names of all
    !!               files whose name starts with cd_var. Return also the 
    !!               number of files.
    !!
    !! ** Method  :  Use a system call that output to a hidden file and then
    !!               read the file to establish the list.
    !!
    !!----------------------------------------------------------------------
    ! Arguments
    CHARACTER(LEN=*),                               INTENT(in ) :: cd_var
    CHARACTER(LEN=255), DIMENSION(:), ALLOCATABLE , INTENT(out) :: cd_list
    INTEGER(KIND=4),                                INTENT(out) :: kfile
    ! Local
    INTEGER(KIND=4) :: jf
    INTEGER(KIND=4) :: inumlst=10
    !!----------------------------------------------------------------------
    CALL SYSTEM( "find . -maxdepth 1 -name """ //  TRIM(cd_var) // "*"" -printf ""%f\n"" | sort -r  > .zbdyfile_list.tmp")
    kfile=0
    OPEN(inumlst, FILE='.zbdyfile_list.tmp')
    DO
       READ(inumlst,*,END=999)
       kfile=kfile+1
    ENDDO
999 PRINT *, 'Files to process : ', kfile
    ALLOCATE( cd_list(kfile) )
    REWIND(inumlst)
    DO jf=1,kfile
       READ(inumlst,"(a)")  cd_list(jf)
    ENDDO
    CLOSE(inumlst)

    CALL SYSTEM( "rm .zbdyfile_list.tmp")

  END SUBROUTINE GetList

END PROGRAM bdy_mk_coordinates
