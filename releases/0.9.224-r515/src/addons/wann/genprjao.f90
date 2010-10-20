subroutine genprjao(ias,lm,ispn,i,wfsvmt,prjao)
use modmain
implicit none
integer, intent(in) :: ias
integer, intent(in) :: lm
integer, intent(in) :: ispn
integer, intent(in) :: i
complex(8), intent(in) :: wfsvmt(lmmaxvr,nrfmax,natmtot,nspinor,nstsv)
complex(8), intent(out) :: prjao

integer l,m1,lm1,io1
! compute <psi_{ik}|phi_n>, where n={ias,lm,ispn} 
! |psi> is a spinor Bloch-function 
! |phi> is a valence local orbital
! 
! Warning: current implementation is for the default APW+lo basis
l=lm2l(lm)
prjao=zzero
do m1=-l,l
  lm1=idxlm(l,m1)
  do io1=1,nrfmax
    prjao=prjao+dconjg(wfsvmt(lm1,io1,ias,ispn,i))*&
      urfprod(l,io1,2,ias)*rylm_lcs(lm,lm1,ias)
  enddo !io1
enddo !m
return
end