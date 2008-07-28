subroutine response
use modmain
implicit none

! allocatable arrays                                                                                                                              
complex(8), allocatable :: evecfv1(:,:)
complex(8), allocatable :: evecsv1(:,:)
complex(8), allocatable :: evecfv2(:,:)
complex(8), allocatable :: evecsv2(:,:)
complex(8), allocatable :: apwalm(:,:,:,:)
complex(8), allocatable :: wfmt1(:,:,:,:,:),wfmt2(:,:,:,:,:)
complex(8), allocatable :: wfir1(:,:,:),wfir2(:,:,:)
complex(8), allocatable :: zrhomt(:,:,:)
complex(8), allocatable :: zrhoir(:)

real(8)                 :: vq0c(3),vkq0l(3),t1,vq0rl(3),vq0rc(3)
integer                 :: ik1,ik2,ist1,ist2,ik,jk,ig,ir,is,i,j,i1,i2,i3,ig1,ig2,ig3,ie
integer                 :: vgq0l(3)
integer                 :: ivg1(3),ivg2(3)
integer   , allocatable :: k1(:)
real(8)   , allocatable :: vgq0c(:,:)
real(8)   , allocatable :: gq0(:)
real(8)   , allocatable :: tpgq0(:,:)
complex(8), allocatable :: sfacgq0(:,:)
complex(8), allocatable :: sfac3g(:)
complex(8), allocatable :: ylmgq0(:,:)
real(8) ,allocatable    :: jlgq0r(:,:,:,:),jl(:)
integer ,allocatable    :: ngknr(:)
integer ,allocatable    :: igkignr(:,:)
real(8) ,allocatable    :: vgklnr(:,:,:),vgkcnr(:,:),gkcnr(:,:),tpgkcnr(:,:,:)
complex(8) ,allocatable :: sfacgknr(:,:,:)
real(8) ,external       :: r3taxi
real(8) ,allocatable    :: occsvnr(:,:)
real                    :: cpu0,cpu1
complex(8) ,allocatable :: chi0(:,:,:)
complex(8) ,allocatable :: chi(:,:)
real(8) ,allocatable    :: evalsvnr(:,:)
complex(8) ,allocatable :: w(:)
! number of G-shells for response
!- integer                 :: ngsh_resp
! number of G-vectors for response (depends on ngsh_resp) 
integer                 :: ngvec_resp

integer                 :: ngvec_me
! number of n,n' combinations of band-indexes for each k-point
integer ,allocatable    :: num_nnp(:)
! maximum num_nnp over all k-points 
integer                 :: max_num_nnp
! pair of n,n' band indexes for each k-point
integer ,allocatable    :: nnp(:,:,:)
! index to G-vector whcih reduces q0 to first BZ 
integer                 :: igq0
! array of Fourier coefficients of complex charge density
complex(8) ,allocatable :: zrhofc(:,:)

complex(8) ,allocatable :: mtrx1(:,:)

real(8) ,allocatable    :: vc(:,:)

integer                 :: nepts
real(8)                 :: emin,emax,de,eta

real(8) ,allocatable    :: docc(:,:)
integer    ,allocatable :: gshell(:)

real(8) ,allocatable    :: kkrel(:,:)

integer                 :: min_band_resp,max_band_resp
logical                 :: flg

integer ,allocatable    :: igfft1(:,:)

real(8)                 :: norm1
complex(8)              :: znorm,zsum1(100)
complex(8)              :: znorm2(3)
real(8)                 :: v1(3)

integer                 :: info
integer ,allocatable    :: ipiv(:)
complex(8)              :: wt
real(8), parameter :: au2ang=0.5291772108d0

complex(8) ,allocatable  :: zrhofc1(:,:)
complex(8) ,external :: zfint

! initialise universal variables
call init0
call init1


if (task.eq.400.or.task.eq.402) then
  allocate(vgklnr(3,ngkmax,nkptnr))
  allocate(vgkcnr(3,ngkmax))
  allocate(gkcnr(ngkmax,nkptnr))
  allocate(tpgkcnr(2,ngkmax,nkptnr))
  allocate(ngknr(nkptnr))
  allocate(sfacgknr(ngkmax,natmtot,nkptnr))
  allocate(igkignr(ngkmax,nkptnr))
! generate G+k vectors for entire BZ (this is required to compute wave-functions at each k-point)
  do ik=1,nkptnr
    call gengpvec(vklnr(1,ik),vkcnr(1,ik),ngknr(ik),igkignr(1,ik),vgklnr(1,1,ik),vgkcnr,gkcnr(1,ik),tpgkcnr(1,1,ik))
    call gensfacgp(ngknr(ik),vgkcnr,ngkmax,sfacgknr(1,1,ik))
  enddo
  allocate(evecfv1(nmatmax,nstfv))
  allocate(evecsv1(nstsv,nstsv))
  allocate(evecfv2(nmatmax,nstfv))
  allocate(evecsv2(nstsv,nstsv))
  allocate(apwalm(ngkmax,apwordmax,lmmaxapw,natmtot))
  allocate(wfmt1(lmmaxvr,nrcmtmax,natmtot,nspinor,nstsv))
  allocate(wfir1(ngrtot,nspinor,nstsv))
  allocate(wfmt2(lmmaxvr,nrcmtmax,natmtot,nspinor,nstsv))
  allocate(wfir2(ngrtot,nspinor,nstsv))
  allocate(zrhomt(lmmaxvr,nrcmtmax,natmtot))
  allocate(zrhoir(ngrtot))

! read the density and potentials from file
  call readstate

! read Fermi energy from file
  call readfermi

! find the new linearisation energies
  call linengy

! generate the APW radial functions
  call genapwfr

! generate the local-orbital radial functions
  call genlofr
endif

open(150,file='RESPONSE.OUT',form='formatted',status='replace')

if (task.eq.400) then
  write(150,'("Calculation of matrix elements <psi_{n,k}|e^{-i(G+q)x}|psi_{n'',k+q}>")')

! find number of G-vectors by given number of G-shells
allocate(gshell(ngvec))
ngvec_resp=1
i=1
j=1
do while (i.le.ngsh_resp)
  gshell(j)=i
  if (abs(gc(j+1)-gc(j)).gt.epslat) then
    i=i+1
  endif
  j=j+1
enddo 
ngvec_resp=j-1
ngvec_me=ngvec_resp

write(150,*)
write(150,'("Number of G-shells for response calculation  :",I4)')ngsh_resp
write(150,'("Number of G-vectors for response calculation :",I4)')ngvec_resp
write(150,*)
write(150,'("  G-vec.       lat.coord.      length(1/a.u.) shell")')
write(150,'(" ---------------------------------------------------")')
do ig=1,ngvec_resp
  write(150,'(2X,I4,4X,3I5,4X,F12.6,5x,I4)')ig,ivg(:,ig),gc(ig),gshell(ig)
enddo

allocate(k1(nkptnr))
allocate(vgq0c(3,ngvec))
allocate(gq0(ngvec))
allocate(tpgq0(2,ngvec))
allocate(sfacgq0(ngvec,natmtot))
allocate(sfac3g(natmtot))
allocate(ylmgq0(lmmaxvr,ngvec))
allocate(jlgq0r(nrcmtmax,0:lmaxvr,nspecies,ngvec))
allocate(jl(0:lmaxvr))
allocate(occsvnr(nstsv,nkptnr))
allocate(igfft1(ngvec_resp,nkptnr))

do i=1,3
  vq0l(i)=vq0l(i)/ngridk(i)
enddo

! find G-vector which brings q0 to first BZ
vgq0l(:)=floor(vq0l(:))

! reduce q0 vector fo first BZ
vq0rl(:)=vq0l(:)-vgq0l(:)

! check if we have enough G-shells to bring q0 back to first BZ
do ig=1,ngvec_resp
  if (sum(abs(vgq0l(:)-ivg(:,ig))).eq.0) then
    igq0=ig
    goto 20
  endif
enddo
write(*,*)
write(*,'("Error(response): not enough G-vectors to reduce q-vector to first BZ")')
write(*,'(" Increase number of G-shells")')
write(*,*)
stop
20 continue

! get q0 and reduced q0 in Cartesian coordinates
call r3mv(bvec,vq0l,vq0c)
call r3mv(bvec,vq0rl,vq0rc)

write(150,*)
write(150,'("q-vector in lattice coordinates              : ",3G18.10)')vq0l
write(150,'("q-vector in Cartesian coordinates (1/a.u.)   : ",3G18.10)')vq0c
write(150,'("q-vector length (1/a.u.)                     : ",G18.10)')sqrt(vq0c(1)**2+vq0c(2)**2+vq0c(3)**2)
write(150,'("q-vector length (1/A)                        : ",G18.10)')sqrt(vq0c(1)**2+vq0c(2)**2+vq0c(3)**2)/0.529177d0
write(150,'("G-vector to reduce q to first BZ (lat.coord.): ",3I4)')vgq0l
write(150,'("Index of G-vector                            : ",I4)')igq0
write(150,'("Reduced q-vector (lat.coord.)                : ",3G18.10)')vq0rl
write(150,'("Reduced q-vector (Cart.coord.)               : ",3G18.10)')vq0rc

! find k+q and reduce them to first BZ (this is required to utilize the 
!   periodical property of Bloch-states: |k>=|k+K>, where K is any vector 
!   of the reciprocal lattice)
write(150,*)
write(150,'("  ik          k                   k+q                K            k''=k+q-K        jk")')
write(150,'("-------------------------------------------------------------------------------------")')
do ik=1,nkptnr
! k+q vector
  vkq0l(:)=vklnr(:,ik)+vq0rl(:)
! K vector
  ivg1(:)=floor(vkq0l(:))
! reduced k+q vector: k'=k+q-K
  vkq0l(:)=vkq0l(:)-ivg1(:)
! search for index of reduced k+q vector 
  do jk=1,nkptnr
    if (r3taxi(vklnr(:,jk),vkq0l).lt.epslat) then
      k1(ik)=jk
      goto 10
    endif
  enddo
  write(*,*)
  write(*,'("Error(response): index of reduced k+q point is not found")')
  write(*,'(" Check q-vector coordinates")')
  write(*,*)
  stop
10 continue
! search for new fft indexes
  do ig=1,ngvec_me
    ivg2(:)=ivg(:,ig)+ivg1(:)
    igfft1(ig,ik)=igfft(ivgig(ivg2(1),ivg2(2),ivg2(3)))
  enddo
  write(150,'(I4,2X,3F6.2,2X,3F6.2,2X,3I4,2X,3F6.2,2X,I4)') &
    ik,vklnr(:,ik),vkq0l+ivg1,ivg1,vkq0l,k1(ik)
enddo

! get occupancy of states
do ik=1,nkptnr
  call getoccsv(vklnr(1,ik),occsvnr(1,ik))
enddo

min_band_resp=1
max_band_resp=nstsv
! setup n,n' stuff
! first, find the maximum size of nnp array
max_num_nnp=0
allocate(num_nnp(nkptnr))
do ik=1,nkptnr
  jk=k1(ik)
  i1=0
  do i=min_band_resp,max_band_resp
    do j=min_band_resp,max_band_resp
      if (abs(occsvnr(i,ik)-occsvnr(j,jk)).gt.1d-10) i1=i1+1
    enddo
  enddo
  num_nnp(ik)=i1
  max_num_nnp=max(max_num_nnp,i1)
enddo
allocate(nnp(nkptnr,max_num_nnp,3))
allocate(docc(nkptnr,max_num_nnp))
! second, setup the nnp array
do ik=1,nkptnr
  jk=k1(ik)
  i1=0
  do i=min_band_resp,max_band_resp
    do j=min_band_resp,max_band_resp
      if (abs(occsvnr(i,ik)-occsvnr(j,jk)).gt.1d-10) then
        i1=i1+1
        nnp(ik,i1,1)=i
        nnp(ik,i1,2)=j
        docc(ik,i1)=occsvnr(i,ik)-occsvnr(j,jk)
      endif
    enddo
  enddo
enddo


allocate(zrhofc(ngvec_resp,max_num_nnp))
allocate(zrhofc1(ngvec_resp,3))

!- write(*,*)'size of wfmt arrays: ', &
!-  2*lmmaxvr*nrcmtmax*natmtot*nspinor*nstsv*16.d0/1024/1024,' Mb'
!- write(*,*)'size of wfir arrays: ', &
!-   2*ngrtot*nspinor*nstsv*16.d0/1024/1024,' Mb'


! generate G+q0 vectors
  do ig=1,ngvec
    vgq0c(:,ig)=vgc(:,ig)+vq0rc(:) 
! get spherical coordinates and length of G+q0
    call sphcrd(vgq0c(:,ig),gq0(ig),tpgq0(:,ig))
! generate spherical harmonics for G+q0
    call genylm(lmaxvr,tpgq0(:,ig),ylmgq0(:,ig))
  enddo

open(160,file='ZRHOFC.OUT',form='unformatted',status='replace')
write(160)nkptnr,ngvec_resp,max_num_nnp,igq0
write(160)gq0(1:ngvec_resp)









write(150,*)
! generate G+q0 vectors
do ig=1,ngvec_resp
  vgq0c(:,ig)=vgc(:,ig)+vq0rc(:)
! get spherical coordinates and length of G+q0
  call sphcrd(vgq0c(:,ig),gq0(ig),tpgq0(:,ig))
! generate spherical harmonics for G+q0
  call genylm(lmaxvr,tpgq0(:,ig),ylmgq0(:,ig))
  write(150,'("ig=",I4," G+q=",3G18.10," |G+q|=",G18.10)')ig,vgq0c(:,ig),gq0(ig)
  do i=1,lmmaxvr
    write(150,'(4x,"lm=",I3,"  Ylm=",2F18.10)'),i,dreal(ylmgq0(i,ig)),dimag(ylmgq0(i,ig))
  enddo
enddo

! generate structure factor for G+q0 vectors
call gensfacgp(ngvec_resp,vgq0c,ngvec,sfacgq0)
  
! generate Bessel functions
do ig=1,ngvec_resp
  do is=1,nspecies
    do ir=1,nrcmt(is)
      t1 = gq0(ig)*rcmt(ir,is)
      call sbessel(lmaxvr,t1,jl)
      jlgq0r(ir,:,is,ig) = jl(:)
    enddo
  enddo
enddo

write(150,*)
do ik=1,nkptnr
  write(150,'("k-point ",I4," out of ",I4)')ik,nkptnr
    
  jk=k1(ik)
  
  write(160)ik,jk
  write(160)num_nnp(ik)
  write(160)nnp(ik,1:num_nnp(ik),1:2)
  write(160)docc(ik,1:num_nnp(ik))
  
! generate wave-functions at k
  call getevecfv(vklnr(1,ik),vgklnr(:,:,ik),evecfv1)
  call getevecsv(vklnr(1,ik),evecsv1) 
  call match(ngknr(ik),gkcnr(:,ik),tpgkcnr(:,:,ik),sfacgknr(:,:,ik),apwalm)
  call genwfsv(.false.,ngknr(ik),igkignr(:,ik),evalsv(1,1),apwalm,evecfv1, &
    evecsv1,wfmt1,wfir1)

! test normalization    
  do i=1,nstsv
    call vnlrho(.true.,wfmt1(:,:,:,:,i),wfmt1(:,:,:,:,i),wfir1(:,:,i), &
      wfir1(:,:,i),zrhomt,zrhoir)
    znorm=zfint(zrhomt,zrhoir)
    if (abs(znorm-1.d0).gt.0.01d0) then
      write(150,'("Warning: bad norm ",G18.10," of wave-function ",&
      & I4," at k-point ",I4)')abs(znorm),i,ik
    endif
  enddo

! generate wave-functions at k+q
  call getevecfv(vklnr(1,jk),vgklnr(:,:,jk),evecfv2)
  call getevecsv(vklnr(1,jk),evecsv2) 
  call match(ngknr(jk),gkcnr(:,jk),tpgkcnr(:,:,jk),sfacgknr(:,:,jk),apwalm)
  call genwfsv(.false.,ngknr(jk),igkignr(:,jk),evalsv(1,1),apwalm,evecfv2, &
    evecsv2,wfmt2,wfir2)
  
  do i=1,num_nnp(ik)
    ist1=nnp(ik,i,1)
    ist2=nnp(ik,i,2)
    call vnlrho(.true.,wfmt1(:,:,:,:,ist1),wfmt2(:,:,:,:,ist2),wfir1(:,:,ist1), &
      wfir2(:,:,ist2),zrhomt,zrhoir)
    call zrhoft(zrhomt,zrhoir,jlgq0r,ylmgq0,sfacgq0,ngvec_me,igfft1(1,ik),zrhofc1)
    zrhofc(:,i)=zrhofc1(:,3)
  enddo
  
  write(160)zrhofc(1:ngvec_resp,1:num_nnp(ik))
enddo !ik
close(160)


deallocate(gshell)
deallocate(k1)
deallocate(vgq0c)
deallocate(gq0)
deallocate(tpgq0)
deallocate(sfacgq0)
deallocate(ylmgq0)
deallocate(jlgq0r)
deallocate(jl)
deallocate(vgklnr)
deallocate(vgkcnr)
deallocate(gkcnr)
deallocate(tpgkcnr)
deallocate(ngknr)
deallocate(sfacgknr)
deallocate(igkignr)
deallocate(occsvnr)
deallocate(num_nnp)
deallocate(nnp)
deallocate(docc)
deallocate(zrhofc)
deallocate(evecfv1)
deallocate(evecsv1)
deallocate(evecfv2)
deallocate(evecsv2)
deallocate(apwalm)
deallocate(wfmt1)
deallocate(wfmt2)
deallocate(wfir1)
deallocate(wfir2)
deallocate(zrhomt)
deallocate(zrhoir)

endif !task.eq.400

if (task.eq.401) then
  write(150,'("Calculation of KS polarisability chi0")')
  emin=0.d0
  emax=80.d0
  de=0.05d0
  eta=0.5d0
  
  write(150,*)'emin=',emin,' (eV)'
  write(150,*)'emax=',emax,' (eV)'
  write(150,*)'de=',de,' (eV)'
  write(150,*)'eta=',eta,' (eV)'
  
  
  
  nepts=1+(emax-emin)/de
  
  open(160,file='ZRHOFC.OUT',form='unformatted',status='old')
  read(160)i1,ngvec_resp,max_num_nnp,igq0
  if (i1.ne.nkptnr) then
    write(*,*)'Error: k-mesh was changed'
    stop
  endif
  allocate(chi0(ngvec_chi0,ngvec_chi0,nepts))
  allocate(chi(ngvec_chi0,nepts))
  allocate(num_nnp(nkptnr))
  allocate(nnp(nkptnr,max_num_nnp,3))
  allocate(docc(nkptnr,max_num_nnp))
  allocate(evalsvnr(nstsv,nkptnr))
  allocate(w(nepts))
  allocate(zrhofc(ngvec_resp,max_num_nnp))  
  allocate(gq0(1:ngvec_resp))
  
  write(150,*)'igq0=',igq0
  
  read(160)gq0(1:ngvec_resp)
  
  do i=1,nepts
    w(i)=dcmplx(emin+de*(i-1),eta)/ha2ev
  enddo
  
  do ik=1,nkptnr
    call getevalsv(vklnr(1,ik),evalsvnr(1,ik))
  enddo
  
  chi0=dcmplx(0.d0,0.d0)
  do ik=1,nkptnr
    write(150,*)'ik=',ik,' out of ',nkptnr
    read(160)i1,jk
    if (i1.ne.ik) then
      write(*,*)'Error reading file ZRHOFC.OUT'
      stop
    endif
    read(160)num_nnp(ik)
    read(160)nnp(ik,1:num_nnp(ik),1:2)
    read(160)docc(ik,1:num_nnp(ik))
    read(160)zrhofc(1:ngvec_resp,1:num_nnp(ik))
    
    do i=1,num_nnp(ik)
      do ie=1,nepts
        wt=docc(ik,i)/(evalsvnr(nnp(ik,i,1),ik)-evalsvnr(nnp(ik,i,2),jk)+w(ie))
        call zgerc(ngvec_chi0,ngvec_chi0,wt,zrhofc(1,i),1,zrhofc(1,i),1,chi0(1,1,ie),ngvec_chi0)
      enddo !ie
    enddo !i
  enddo !ik
  close(160)
  
  chi0=chi0/nkptnr/omega
  
  open(160,file='chi0.dat',form='formatted',status='replace')
  do ie=1,nepts
    write(160,'(7G18.10)')dreal(w(ie)), &
      dreal(chi0(igq0,igq0,ie)),dimag(chi0(igq0,igq0,ie))
  enddo
  close(160)
  
  allocate(vc(ngvec_chi0,ngvec_chi0))
  allocate(mtrx1(ngvec_chi0,ngvec_chi0))
  vc=0.d0
  do ig=1,ngvec_chi0
    vc(ig,ig)=fourpi/gq0(ig)**2
  enddo
  
  write(150,*)
  write(150,'("Coulomb potential matrix elements:")')
  do ig=1,ngvec_chi0
    write(150,'(I4,2x,2G18.10)')ig,gq0(ig),vc(ig,ig)
  enddo
  
  allocate(ipiv(ngvec_chi0))
  write(150,*)
  do ie=1,nepts
    write(150,*)'energy point ',ie,' out of ',nepts
    if (ie.eq.1) then
      write(150,'("chi0 at first omega:")')
      do i=1,ngvec_chi0
        write(150,'(255G18.10)')(dreal(chi0(i,j,1)),j=1,ngvec_chi0)
	write(150,'(255G18.10)')(dimag(chi0(i,j,1)),j=1,ngvec_chi0)
	write(150,*)
      enddo
    endif
! compute 1-chi0*V
    do i=1,ngvec_chi0
      do j=1,ngvec_chi0
        mtrx1(i,j)=-chi0(i,j,ie)*vc(j,j)
      enddo
      mtrx1(i,i)=dcmplx(1.d0,0.d0)+mtrx1(i,i)
    enddo
    if (ie.eq.1) then
      write(150,'("1-chi0*V at first omega:")')
      do i=1,ngvec_chi0
        write(150,'(255G18.10)')(dreal(mtrx1(i,j)),j=1,ngvec_chi0)
	write(150,'(255G18.10)')(dimag(mtrx1(i,j)),j=1,ngvec_chi0)
	write(150,*)
      enddo
    endif
! solve [1-chi0*V]^{-1}*chi=chi0
    chi(:,ie)=chi0(:,igq0,ie)
    call zgesv(ngvec_chi0,1,mtrx1,ngvec_chi0,ipiv,chi(1,ie),ngvec_chi0,info)
    if (info.ne.0) then
      write(*,*)'Error solving linear equations'
      write(*,*)'info=',info
      stop
    endif
  enddo !ie
  deallocate(ipiv)
  
  
  chi0=chi0/ha2ev/(au2ang)**3
  chi=chi/ha2ev/(au2ang)**3

!  allocate(kkrel(nepts,2))
!  kkrel=0.d0
!  
!  do ie=1,nepts
!    do i=1,nepts-1
!      if (i.eq.ie) cycle
!      kkrel(ie,1)=kkrel(ie,1)+2*(w(i+1)-w(i))*w(i)*dimag(chi0(igq0,igq0,i))/(w(i)**2-w(ie)**2)/pi
!      kkrel(ie,2)=kkrel(ie,2)-2*w(ie)*(w(i+1)-w(i))*dreal(chi0(igq0,igq0,i))/(w(i)**2-w(ie)**2)/pi
!    enddo
!  enddo
  
  open(160,file='resp.dat',form='formatted',status='replace')
  !do igq0=1,ngvec_chi0
    do ie=1,nepts
      write(160,'(7G18.10)')dreal(w(ie))*ha2ev, &
        dreal(chi0(igq0,igq0,ie)),dimag(chi0(igq0,igq0,ie)), &
        dreal(chi(igq0,ie)),dimag(chi(igq0,ie))
    enddo
    write(160,*)
  !enddo
  close(160)
endif



if (task.eq.402) then
  write(150,'("Checking normalization of wave-functions")')
  do ik=1,nkptnr
! generate wave-functions at k
    call getevecfv(vklnr(1,ik),vgklnr(:,:,ik),evecfv1)
    call getevecsv(vklnr(1,ik),evecsv1) 
    call match(ngknr(ik),gkcnr(:,ik),tpgkcnr(:,:,ik),sfacgknr(:,:,ik),apwalm)
    call genwfsv(.false.,ngknr(ik),igkignr(:,ik),evalsv(1,1),apwalm,evecfv1, &
      evecsv1,wfmt1,wfir1)
    do jk=ik,nkptnr
! generate wave-functions at k'
      call getevecfv(vklnr(1,jk),vgklnr(:,:,jk),evecfv2)
      call getevecsv(vklnr(1,jk),evecsv2) 
      call match(ngknr(jk),gkcnr(:,jk),tpgkcnr(:,:,jk),sfacgknr(:,:,jk),apwalm)
      call genwfsv(.false.,ngknr(jk),igkignr(:,jk),evalsv(1,1),apwalm,evecfv2, &
        evecsv2,wfmt2,wfir2)
      do i=1,nstsv
        do j=1,nstsv
	  call vnlrho(.true.,wfmt1(:,:,:,:,i),wfmt2(:,:,:,:,j),wfir1(:,:,i), &
            wfir2(:,:,j),zrhomt,zrhoir)
	  v1=vkcnr(:,jk)-vkcnr(:,ik)
	  call zrhoint(zrhomt,zrhoir,znorm2,v1)
	  znorm=zfint(zrhomt,zrhoir)
          write(150,'("<",I3.3",",I3.3,"|",I3.3,",",I3.3,"> = ",F12.6," + ",F12.6," = ",2F12.6)') &
	    i,ik,j,jk,abs(znorm2(1)),abs(znorm2(2)),abs(znorm2(3)),abs(znorm)
	    
	  !call wfint(wfmt1(:,:,:,1,i),wfir1(:,1,i),wfmt2(:,:,:,1,j),wfir2(:,1,j),znorm)
	  !if (abs(znorm-znorm2).gt.0.1) then
	  !    write(150,*)'Diff norm:',znorm,znorm2
	  !endif
	  !if (i.eq.j.and.ik.eq.jk) then
	  !    if (abs(1.d0-znorm).gt.0.1) then
          !      write(150,*)
          !      write(150,'("Warning: norm of state ",I6," at k-point ",I6," is bad")')i,ik
          !      write(150,'(" norm: ",2G18.10)')znorm
          !      write(150,*)
	  !    endif
	  !else
	  !    if (abs(znorm).gt.0.1) then
          !      write(150,*)
          !      write(150,'("Warning: orthogonality of states ",I6, &
	  !      & " and ",I6," at k-point ",I6," and k-point ",I6, &
	  !      & " is bad")')i,j,ik,jk
          !      write(150,'(" <psi|psi''>: ",2G18.10)')znorm
          !      write(150,*)
	  !    endif
	  !endif
        enddo !j
      enddo !i
    enddo !jk
  enddo !ik
endif

close(150)
return
end

subroutine test1(dvkc,sfacgq0,jlgq0r)
use modmain
implicit none
real(8)    ,intent(in)    :: jlgq0r(nrcmtmax,0:lmaxvr,nspecies,ngvec)                                                                             
complex(8) ,intent(in)    :: sfacgq0(ngvec,natmtot)
real(8)    ,intent(in)    :: dvkc(3)

complex(8) ,allocatable :: zir(:)
integer i1,i2,i3,n,ir,is,nr,ia,ias
real(8) v(3),t1,t2
complex(8) zsum,zsumir,zsummt,ztmp
real(8) ,allocatable      :: fr1(:),fr2(:),gr(:),cf(:,:)
                                                                                                                                                  
allocate(fr1(nrcmtmax),fr2(nrcmtmax),gr(nrcmtmax),cf(3,nrcmtmax))
allocate(zir(ngrtot))

!n=0
!zsum=dcmplx(0.d0,0.d0)
!do i3=ngrid(3)/2-ngrid(3)+1,ngrid(3)/2
!  do i2=ngrid(2)/2-ngrid(2)+1,ngrid(2)/2
!    do i1=ngrid(1)/2-ngrid(1)+1,ngrid(1)/2
!      n=n+1
!      v(:)=i1*avec(:,1)/ngrid(1)+i2*avec(:,2)/ngrid(2)+i3*avec(:,3)/ngrid(3)
!      zir(n)=exp(dcmplx(0.d0,dot_product(v,dvkc)))
!      zsum=zsum+zir(n)/ngrtot*omega
!    enddo
! enddo
!enddo

zsum=dcmplx(0.d0,0.d0)
do i3=0,ngrid(3)-1
  do i2=0,ngrid(2)-1
    do i1=0,ngrid(1)-1
      n=1+i2+i2*ngrid(1)+i3*ngrid(1)*ngrid(2)
      v(:)=i1*avec(:,1)/ngrid(1)+i2*avec(:,2)/ngrid(2)+i3*avec(:,3)/ngrid(3)
      zir(n)=exp(dcmplx(0.d0,dot_product(v,dvkc)))
      zsum=zsum+zir(n)/ngrtot*omega
    enddo
  enddo
enddo
call zfftifc(3,ngrid,-1,zir)
write(150,*)zsum,zir(igfft(1)),zir(igfft(1:30))
stop

zsumir=dcmplx(0.d0,0.d0)
do ir=1,ngrtot
  zsumir=zsumir+zir(ir)*cfunir(ir)/ngrtot*omega
enddo

zsummt=dcmplx(0.d0,0.d0)
do is=1,nspecies
  nr=nrcmt(is)
  do ia=1,natoms(is)
    ias=idxas(ia,is)
    do ir=1,nr
      ztmp=jlgq0r(ir,0,is,1)
      !write(20,*)rcmt(ir,is),jlgq0r(ir,0,is,1)
      t1=rcmt(ir,is)**2
      fr1(ir)=dreal(ztmp)*t1
      fr2(ir)=dimag(ztmp)*t1
    enddo !ir
    call fderiv(-1,nr,rcmt(:,is),fr1,gr,cf)
    t1=gr(nr)
    call fderiv(-1,nr,rcmt(:,is),fr2,gr,cf)
    t2=gr(nr)
    zsummt=zsummt+(fourpi)*sfacgq0(1,ias)*dcmplx(t1,t2)
  enddo
enddo

write(150,*)zsum,zsumir,zsummt,zsumir+zsummt
!stop

deallocate(zir,fr1,fr2,gr,cf)
return
end


subroutine wfint(wfmt1,wfir1,wfmt2,wfir2,norm)
use modmain
implicit none
complex(8) ,intent(in)    :: wfmt1(lmmaxvr,nrcmtmax,natmtot)
complex(8) ,intent(in)    :: wfir1(ngrtot)
complex(8) ,intent(in)    :: wfmt2(lmmaxvr,nrcmtmax,natmtot)
complex(8) ,intent(in)    :: wfir2(ngrtot)
complex(8) ,intent(out)   :: norm

integer is,nr,ia,ias,ir,l,m,lm
real(8) ,allocatable   :: fr1(:),fr2(:),gr(:),cf(:,:) 
real(8) t1,t2                                                                                           
complex(8) ,allocatable :: wfmt1y(:,:),wfmt2y(:,:)
complex(8) sumir,summt,sum1
                                                                                                                                                  
allocate(fr1(nrcmtmax),fr2(nrcmtmax),gr(nrcmtmax),cf(3,nrcmtmax))
allocate(wfmt1y(lmmaxvr,nrcmtmax),wfmt2y(lmmaxvr,nrcmtmax))

! interstitial part
sumir=dcmplx(0.d0,0.d0)
do ir=1,ngrtot
  sumir=sumir+cfunir(ir)*wfir1(ir)*dconjg(wfir2(ir))
enddo
sumir=sumir*omega/ngrtot

! muffin-tin part
summt=dcmplx(0.d0,0.d0)
do is=1,nspecies
  nr=nrcmt(is)
  do ia=1,natoms(is) 
    ias=idxas(ia,is)
! transform to spherical harmonics
    call zgemm('N','N',lmmaxvr,nr,lmmaxvr,zone,zfshtvr,lmmaxvr,wfmt1(1,1,ias), &
      lmmaxvr,zzero,wfmt1y,lmmaxvr)
    call zgemm('N','N',lmmaxvr,nr,lmmaxvr,zone,zfshtvr,lmmaxvr,wfmt2(1,1,ias), &
      lmmaxvr,zzero,wfmt2y,lmmaxvr)
    do ir=1,nr
      sum1=dcmplx(0.d0,0.d0)
      do l=0,lmaxvr
        do m=-l,l
          lm=idxlm(l,m)
          sum1=sum1+wfmt1y(lm,ir)*dconjg(wfmt2y(lm,ir))
	enddo !m
      enddo !l
      t1=rcmt(ir,is)**2
      fr1(ir)=dreal(sum1)*t1
      fr2(ir)=dimag(sum1)*t1
    enddo !ir
    call fderiv(-1,nr,rcmt(:,is),fr1,gr,cf)
    t1=gr(nr)
    call fderiv(-1,nr,rcmt(:,is),fr2,gr,cf)
    t2=gr(nr)
    summt=summt+dcmplx(t1,t2)
  enddo !ia
enddo !is
  
norm=sumir+summt

deallocate(fr1,fr2,gr,cf)
deallocate(wfmt1y,wfmt2y)
return
end

subroutine zrhoint(zwfmt,zwfir,norm,vdkc)
use modmain
implicit none
complex(8) ,intent(in)    :: zwfmt(lmmaxvr,nrcmtmax,natmtot)
complex(8) ,intent(in)    :: zwfir(ngrtot)
complex(8) ,intent(out)   :: norm(3)
real(8)    ,intent(inout) :: vdkc(3)


integer is,nr,ia,ias,ir,ig,l,m,lm
real(8) ,allocatable   :: fr1(:),fr2(:),gr(:),cf(:,:) 
real(8) t1,t2                                                                                           
complex(8) ,allocatable :: wfmt1y(:,:),wfmt2y(:,:)
complex(8) sumir,summt,sum1
real(8)   :: dk,tpdk(2)
complex(8) :: ylmdk(lmmaxvr),sfacdk(natmtot),zsum1,zsum2
real(8) ,allocatable :: jl(:,:) 
integer i1,i2,i3
real(8) t(3) 
complex(8) zph                
                                                                                                      
allocate(fr1(nrcmtmax),fr2(nrcmtmax),gr(nrcmtmax),cf(3,nrcmtmax))
allocate(wfmt1y(lmmaxvr,nrcmtmax),wfmt2y(lmmaxvr,nrcmtmax))
allocate(jl(0:lmaxvr,nrcmtmax))

zph=dcmplx(0.d0,0.d0)
do i1=0,ngridk(1)-1
  do i2=0,ngridk(2)-1
    do i3=0,ngridk(3)-1
      t=i1*avec(:,1)+i2*avec(:,2)+i3*avec(:,3)
      zph=zph+exp(dcmplx(0.d0,dot_product(vdkc,t)))/nkptnr
    enddo
  enddo
enddo

vdkc=-vdkc
vdkc=0.d0

call sphcrd(vdkc,dk,tpdk)
call genylm(lmaxvr,tpdk,ylmdk)
call gensfacgp(1,vdkc,1,sfacdk)

! interstitial part
sumir=dcmplx(0.d0,0.d0)
do ir=1,ngrtot
  sumir=sumir+cfunir(ir)*zwfir(ir)
enddo
sumir=sumir*omega/ngrtot

! muffin-tin part
summt=dcmplx(0.d0,0.d0)
do is=1,nspecies
  nr=nrcmt(is)
  do ir=1,nr
    t1=dk*rcmt(ir,is)
    call sbessel(lmaxvr,t1,jl(0,ir))
  enddo
  do ia=1,natoms(is) 
    ias=idxas(ia,is)
    do ir=1,nr
      zsum1=dcmplx(0.d0,0.d0)
      do l=0,lmaxvr
        zsum2=dcmplx(0.d0,0.d0)
        do m=-l,l
	  lm=idxlm(l,m)
	  zsum2=zsum2+zwfmt(lm,ir,ias)*ylmdk(lm)
	enddo
	zsum1=zsum1+jl(l,ir)*conjg(zil(l))*zsum2
      enddo
      t1=rcmt(ir,is)**2
      fr1(ir)=dreal(zsum1)*t1
      fr2(ir)=dimag(zsum1)*t1
    enddo !ir
    call fderiv(-1,nr,rcmt(:,is),fr1,gr,cf)
    t1=gr(nr)
    call fderiv(-1,nr,rcmt(:,is),fr2,gr,cf)
    t2=gr(nr)
    summt=summt+fourpi*conjg(sfacdk(ias))*dcmplx(t1,t2)
  enddo !ia
enddo !is

norm(1)=summt
norm(2)=sumir
norm(3)=(sumir+summt)*zph

deallocate(jl)
deallocate(fr1,fr2,gr,cf)
deallocate(wfmt1y,wfmt2y)
return
end
