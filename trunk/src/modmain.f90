
! Copyright (C) 2002-2008 J. K. Dewhurst, S. Sharma and C. Ambrosch-Draxl.
! This file is distributed under the terms of the GNU General Public License.
! See the file COPYING for license details.

module modmain
use mod_mpi_grid
use mod_timer
use mod_hdf5

!----------------------------!
!     lattice parameters     !
!----------------------------!
! lattice vectors stored column-wise
real(8) avec(3,3)
! inverse of lattice vector matrix
real(8) ainv(3,3)
! reciprocal lattice vectors
real(8) bvec(3,3)
! inverse of reciprocal lattice vector matrix
real(8) binv(3,3)
! unit cell volume
real(8) omega
! any vector with length less than epslat is considered zero
real(8) epslat

!--------------------------!
!     atomic variables     !
!--------------------------!
! maximum allowed species
integer, parameter :: maxspecies=8
! maximum allowed atoms per species
integer, parameter :: maxatoms=200
! number of species
integer nspecies
! number of atoms for each species
integer natoms(maxspecies)
! maximum number of atoms over all the species
integer natmmax
! total number of atoms
integer natmtot
! index to atoms and species
integer idxas(maxatoms,maxspecies)
! molecule is .true. is the system is an isolated molecule
logical molecule
! primcell is .true. if primitive unit cell is to be found automatically
logical primcell
! atomic positions in lattice coordinates
real(8) atposl(3,maxatoms,maxspecies)
! atomic positions in Cartesian coordinates
real(8) atposc(3,maxatoms,maxspecies)

!----------------------------------!
!     atomic species variables     !
!----------------------------------!
! species files path
character(256) sppath
! species filenames
character(256) spfname(maxspecies)
! species name
character(256) spname(maxspecies)
! species symbol
character(256) spsymb(maxspecies)
! species nuclear charge
real(8) spzn(maxspecies)
! ptnucl is .true. if the nuclei are to be treated as point charges, if .false.
! the nuclei have a finite spherical distribution
logical ptnucl
! species electronic charge
real(8) spze(maxspecies)
! species mass
real(8) spmass(maxspecies)
! smallest radial point for each species
real(8) sprmin(maxspecies)
! effective infinity for species
real(8) sprmax(maxspecies)
! number of radial points to effective infinity for each species
integer spnr(maxspecies)
! maximum spnr over all the species
integer spnrmax
! maximum allowed states for each species
integer, parameter :: maxspst=40
! number of states for each species
integer spnst(maxspecies)
! maximum spnst over all the species
integer spnstmax
! state principle quantum number for each species
integer spn(maxspst,maxspecies)
! state l value for each species
integer spl(maxspst,maxspecies)
! state k value for each species
integer spk(maxspst,maxspecies)
! spcore is .true. if species state is core
logical spcore(maxspst,maxspecies)
! state eigenvalue for each species
real(8) speval(maxspst,maxspecies)
! state occupancy for each species
real(8) spocc(maxspst,maxspecies)
! species radial mesh
real(8), allocatable :: spr(:,:)
! species charge density
real(8), allocatable :: sprho(:,:)
! species self-consistent potential
real(8), allocatable :: spvr(:,:)

!---------------------------------------------------------------!
!     muffin-tin radial mesh and angular momentum variables     !
!---------------------------------------------------------------!
! radial function integration and differentiation polynomial order
integer nprad
! number of muffin-tin radial points for each species
integer nrmt(maxspecies)
! maximum nrmt over all the species
integer nrmtmax
! autormt is .true. for automatic determination of muffin-tin radii
logical autormt
! parameters for determining muffin-tin radii automatically
real(8) rmtapm(2)
! muffin-tin radii
real(8) rmt(maxspecies)
! species for which the muffin-tin radius will be used for calculating gkmax
integer isgkmax
! radial step length for coarse mesh
integer lradstp
! number of coarse radial mesh points
integer nrcmt(maxspecies)
! maximum nrcmt over all the species
integer nrcmtmax
! coarse muffin-tin radial mesh
real(8), allocatable :: rcmt(:,:)
! maximum allowable angular momentum for augmented plane waves
integer, parameter :: maxlapw=50
! maximum angular momentum for augmented plane waves
integer lmaxapw
! (lmaxapw+1)^2
integer lmmaxapw
! maximum angular momentum for potentials and densities
integer lmaxvr
! (lmaxvr+1)^2
integer lmmaxvr
! maximum angular momentum used when evaluating the Hamiltonian matrix elements
integer lmaxmat
! (lmaxmat+1)^2
integer lmmaxmat
! fraction of muffin-tin radius which constitutes the inner part
real(8) fracinr
! maximum angular momentum in the inner part of the muffin-int
integer lmaxinr
! (lmaxinr+1)^2
integer lmmaxinr
! number of radial points to the inner part of the muffin-tin
integer nrmtinr(maxspecies)
! index to (l,m) pairs
integer, allocatable :: idxlm(:,:)

!--------------------------------!
!     spin related variables     !
!--------------------------------!
! spinpol is .true. for spin-polarised calculations
logical spinpol
! spinorb is .true. for spin-orbit coupling
logical spinorb
! fixspin type: 0 = none, 1 = global, 2 = local, 3 = global + local
integer fixspin
! dimension of magnetisation and magnetic vector fields (1 or 3)
integer ndmag
! ncmag is .true. if the magnetisation is non-collinear, i.e. when ndmag = 3
logical ncmag
! fixed total spin magnetic moment
real(8) momfix(3)
! fixed spin moment global effective field in Cartesian coordinates
real(8) bfsmc(3)
! muffin-tin fixed spin moments
real(8) mommtfix(3,maxatoms,maxspecies)
! muffin-tin fixed spin moment effective fields in Cartesian coordinates
real(8) bfsmcmt(3,maxatoms,maxspecies)
! fixed spin moment field mixing parameter
real(8) taufsm
! second-variational spinor dimension (1 or 2)
integer nspinor
! external magnetic field in each muffin-tin in lattice coordinates
real(8) bflmt(3,maxatoms,maxspecies)
! external magnetic field in each muffin-tin in Cartesian coordinates
real(8) bfcmt(3,maxatoms,maxspecies)
! global external magnetic field in lattice coordinates
real(8) bfieldl(3)
! global external magnetic field in Cartesian coordinates
real(8) bfieldc(3)
! external magnetic fields are multiplied by reducebf after each iteration
real(8) reducebf
! spinsprl if .true. if a spin-spiral is to be calculated
logical spinsprl
! number of spin-dependent first-variational functions per state
integer nspnfv
! spin-spiral q-vector in lattice coordinates
real(8) vqlss(3)
! spin-spiral q-vector in Cartesian coordinates
real(8) vqcss(3)

!----------------------------!
!     symmetry variables     !
!----------------------------!
! nosym is .true. if no symmetry information should be used
logical nosym
! number of Bravais lattice point group symmetries
integer nsymlat
! Bravais lattice point group symmetries
integer symlat(3,3,48)
! determinants of lattice symmetry matrices (1 or -1)
integer symlatd(48)
! index to inverses of the lattice symmetries
integer isymlat(48)
! lattice point group symmetries in Cartesian coordinates
real(8) symlatc(3,3,48)
! tshift is .true. if atomic basis is allowed to be shifted
logical tshift
! maximum of symmetries allowed
integer, parameter :: maxsymcrys=192
! number of crystal symmetries
integer nsymcrys
! crystal symmetry translation vector in lattice coordinates
real(8) vtlsymc(3,maxsymcrys)
! spatial rotation element in lattice point group for each crystal symmetry
integer lsplsymc(maxsymcrys)
! global spin rotation element in lattice point group for each crystal symmetry
integer lspnsymc(maxsymcrys)
! equivalent atom index for each crystal symmetry
integer, allocatable :: ieqatom(:,:,:)
! eqatoms(ia,ja,is) is .true. if atoms ia and ja are equivalent
logical, allocatable :: eqatoms(:,:,:)
! number of site symmetries
integer, allocatable :: nsymsite(:)
! site symmetry spatial rotation element in lattice point group
integer, allocatable :: lsplsyms(:,:)
! site symmetry global spin rotation element in lattice point group
integer, allocatable :: lspnsyms(:,:)

!--------------------------------!
!     G-vector set variables     !
!--------------------------------!
! G-vector cut-off for interstitial potential and density
real(8) gmaxvr
! G-vector grid sizes
integer ngrid(3)
! total number of G-vectors
integer ngrtot
! integer grid intervals for each direction
integer intgv(3,2)
! number of G-vectors with G < gmaxvr
integer ngvec
! G-vector integer coordinates
integer, allocatable :: ivg(:,:)
! map from integer grid to G-vector array
integer, allocatable :: ivgig(:,:,:)
! map from G-vector array to FFT array
integer, allocatable :: igfft(:)
! G-vectors in Cartesian coordinates
real(8), allocatable :: vgc(:,:)
! length of G-vectors
real(8), allocatable :: gc(:)
! spherical harmonics of the G-vectors
complex(8), allocatable :: ylmg(:,:)
! structure factor for the G-vectors
complex(8), allocatable :: sfacg(:,:)
! G-space characteristic function: 0 inside the muffin-tins and 1 outside
complex(8), allocatable :: cfunig(:)
! real-space characteristic function: 0 inside the muffin-tins and 1 outside
real(8), allocatable :: cfunir(:)
! damping coefficient for characteristic function
real(8) cfdamp

!-------------------------------!
!     k-point set variables     !
!-------------------------------!
! autokpt is .true. if the k-point set is determined automatically
logical autokpt
! radius of sphere used to determine k-point density when autokpt is .true.
real(8) radkpt
! k-point grid sizes
integer ngridk(3)
! total number of k-points
integer nkpt
! k-point offset
real(8) vkloff(3)
! reducek is .true. if k-points are to be reduced (with crystal symmetries)
logical reducek
! locations of k-points on integer grid
integer, allocatable :: ivk(:,:)
! k-points in lattice coordinates
real(8), allocatable :: vkl(:,:)
! k-points in Cartesian coordinates
real(8), allocatable :: vkc(:,:)
! k-point weights
real(8), allocatable :: wkpt(:)
! map from non-reduced grid to reduced set
integer, allocatable :: ikmap(:,:,:)
! total number of non-reduced k-points
integer nkptnr
! locations of non-reduced k-points on integer grid
integer, allocatable :: ivknr(:,:)
! non-reduced k-points in lattice coordinates
real(8), allocatable :: vklnr(:,:)
! non-reduced k-points in Cartesian coordinates
real(8), allocatable :: vkcnr(:,:)
! non-reduced k-point weights
real(8), allocatable :: wkptnr(:)
! map from non-reduced grid to non-reduced set
integer, allocatable :: ikmapnr(:,:,:)
! k-point at which to determine effective mass tensor
real(8) vklem(3)
! displacement size for computing the effective mass tensor
real(8) deltaem
! number of displacements in each direction
integer ndspem

!----------------------------------!
!     G+k-vector set variables     !
!----------------------------------!
! smallest muffin-tin radius times gkmax
real(8) rgkmax
! maximum |G+k| cut-off for APW functions
real(8) gkmax
! number of G+k-vectors for augmented plane waves
integer, allocatable :: ngk(:,:)
! maximum number of G+k-vectors over all k-points
integer ngkmax
! index from G+k-vectors to G-vectors
integer, allocatable :: igkig(:,:,:)
! G+k-vectors in lattice coordinates
real(8), allocatable :: vgkl(:,:,:,:)
! G+k-vectors in Cartesian coordinates
real(8), allocatable :: vgkc(:,:,:,:)
! length of G+k-vectors
real(8), allocatable :: gkc(:,:,:)
! (theta, phi) coordinates of G+k-vectors
real(8), allocatable :: tpgkc(:,:,:,:)
! structure factor for the G+k-vectors
complex(8), allocatable :: sfacgk(:,:,:,:)

!-------------------------------!
!     q-point set variables     !
!-------------------------------!
! q-point grid sizes
integer ngridq(3)
! total number of q-points
integer nqpt
! reduceq is .true. if q-points are to be reduced (with crystal symmetries)
logical reduceq
! locations of q-points on integer grid
integer, allocatable :: ivq(:,:)
! map from non-reduced grid to reduced set
integer, allocatable :: iqmap(:,:,:)
! q-points in lattice coordinates
real(8), allocatable :: vql(:,:)
! q-points in Cartesian coordinates
real(8), allocatable :: vqc(:,:)
! q-point weights
real(8), allocatable :: wqpt(:)
! weights associated with the integral of 1/q^2
real(8), allocatable :: wiq2(:)

!-----------------------------------------------------!
!     spherical harmonic transform (SHT) matrices     !
!-----------------------------------------------------!
! real backward SHT matrix for lmaxapw
real(8), allocatable :: rbshtapw(:,:)
! real forward SHT matrix for lmmaxapw
real(8), allocatable :: rfshtapw(:,:)
! real backward SHT matrix for lmaxvr
real(8), allocatable :: rbshtvr(:,:)
! real forward SHT matrix for lmaxvr
real(8), allocatable :: rfshtvr(:,:)
! complex backward SHT matrix for lmaxapw
complex(8), allocatable :: zbshtapw(:,:)
! complex forward SHT matrix for lmaxapw
complex(8), allocatable :: zfshtapw(:,:)
! complex backward SHT matrix for lmaxvr
complex(8), allocatable :: zbshtvr(:,:)
! complex forward SHT matrix for lmaxvr
complex(8), allocatable :: zfshtvr(:,:)

!-----------------------------------------!
!     potential and density variables     !
!-----------------------------------------!
! exchange-correlation functional type
integer xctype
! exchange-correlation functional description
character(256) xcdescr
! exchange-correlation functional spin treatment
integer xcspin
! exchange-correlation functional density gradient treatment
integer xcgrad
! muffin-tin charge density
real(8), allocatable :: rhomt(:,:,:)
! interstitial real-space charge density
real(8), allocatable :: rhoir(:)
! muffin-tin magnetisation vector field
real(8), allocatable :: magmt(:,:,:,:)
! interstitial magnetisation vector field
real(8), allocatable :: magir(:,:)
! muffin-tin Coulomb potential
real(8), allocatable :: vclmt(:,:,:)
! interstitial real-space Coulomb potential
real(8), allocatable :: vclir(:)
! order of polynomial for pseudocharge density
integer npsden
! muffin-tin exchange-correlation potential
real(8), allocatable :: vxcmt(:,:,:)
! interstitial real-space exchange-correlation potential
real(8), allocatable :: vxcir(:)
! muffin-tin exchange-correlation magnetic field
real(8), allocatable :: bxcmt(:,:,:,:)
! interstitial exchange-correlation magnetic field
real(8), allocatable :: bxcir(:,:)
! nosource is .true. if the field is to be made source-free
logical nosource
! muffin-tin effective potential
real(8), allocatable :: veffmt(:,:,:)
! interstitial effective potential
real(8), allocatable :: veffir(:)
! G-space interstitial effective potential
complex(8), allocatable :: veffig(:)
! muffin-tin exchange energy density
real(8), allocatable :: exmt(:,:,:)
! interstitial real-space exchange energy density
real(8), allocatable :: exir(:)
! muffin-tin correlation energy density
real(8), allocatable :: ecmt(:,:,:)
! interstitial real-space correlation energy density
real(8), allocatable :: ecir(:)
! type of mixing to use for the potential
integer mixtype
! adaptive mixing parameters
real(8) beta0
real(8) betainc
real(8) betadec

!-------------------------------------!
!     charge and moment variables     !
!-------------------------------------!
! tolerance for error in total charge
real(8) epschg
! total nuclear charge
real(8) chgzn
! total core charge
real(8) chgcr
! core leakage charge
real(8) chgcrlk
! total valence charge
real(8) chgval
! excess charge
real(8) chgexs
! total charge
real(8) chgtot
! calculated total charge
real(8) chgcalc
! interstitial region charge
real(8) chgir
! muffin-tin charges
real(8), allocatable :: chgmt(:)
! total muffin-tin charge
real(8) chgmttot
! effective Wigner radius
real(8) rwigner
! total moment
real(8) momtot(3)
! interstitial region moment
real(8) momir(3)
! muffin-tin moments
real(8), allocatable :: mommt(:,:)
! total muffin-tin moment
real(8) mommttot(3)

!-----------------------------------------!
!     APW and local-orbital variables     !
!-----------------------------------------!
! maximum allowable APW order
integer, parameter :: maxapword=3
! APW order
integer apword(0:maxlapw,maxspecies)
! maximum of apword over all angular momenta and species
integer apwordmax
! APW initial linearisation energies
real(8) apwe0(maxapword,0:maxlapw,maxspecies)
! APW linearisation energies
real(8), allocatable :: apwe(:,:,:)
! APW derivative order
integer apwdm(maxapword,0:maxlapw,maxspecies)
! apwve is .true. if the linearisation energies are allowed to vary
logical apwve(maxapword,0:maxlapw,maxspecies)
! APW radial functions
real(8), allocatable :: apwfr(:,:,:,:,:)
! derivate of radial functions at the muffin-tin surface
real(8), allocatable :: apwdfr(:,:,:)
! maximum number of local-orbitals
integer, parameter :: maxlorb=20
! maximum allowable local-orbital order
integer, parameter :: maxlorbord=4
! number of local-orbitals
integer nlorb(maxspecies)
! maximum nlorb over all species
integer nlomax
! total number of local-orbitals
integer nlotot
! local-orbital order
integer lorbord(maxlorb,maxspecies)
! local-orbital angular momentum
integer lorbl(maxlorb,maxspecies)
! maximum lorbl over all species
integer lolmax
! (lolmax+1)^2
integer lolmmax
! local-orbital initial energies
real(8) lorbe0(maxlorbord,maxlorb,maxspecies)
! local-orbital energies
real(8), allocatable :: lorbe(:,:,:)
! local-orbital derivative order
integer lorbdm(maxlorbord,maxlorb,maxspecies)
! lorbve is .true. if the linearisation energies are allowed to vary
logical lorbve(maxlorbord,maxlorb,maxspecies)
! local-orbital radial functions
real(8), allocatable :: lofr(:,:,:,:)
! energy step size for locating the band energy
real(8) deband

!-------------------------------------------!
!     overlap and Hamiltonian variables     !
!-------------------------------------------!
! order of overlap and Hamiltonian matrices for each k-point
integer, allocatable :: nmat(:,:)
! maximum nmat over all k-points
integer nmatmax
! size of packed matrices
integer, allocatable :: npmat(:,:)
! index to the position of the local-orbitals in the H and O matrices
integer, allocatable :: idxlo(:,:,:)
! APW-local-orbital overlap integrals
real(8), allocatable :: oalo(:,:,:)
! local-orbital-local-orbital overlap integrals
real(8), allocatable :: ololo(:,:,:)
! APW-APW Hamiltonian integrals
real(8), allocatable :: haa(:,:,:,:,:,:)
! local-orbital-APW Hamiltonian integrals
real(8), allocatable :: hloa(:,:,:,:,:)
! local-orbital-local-orbital Hamiltonian integrals
real(8), allocatable :: hlolo(:,:,:,:)
! complex Gaunt coefficient array
complex(8), allocatable :: gntyry(:,:,:)
! tseqit is .true. if the first-variational secular equation is to be solved
! iteratively
logical tseqit
! number of secular equation iterations per self-consistent loop
integer nseqit
! iterative solver step length
real(8) tauseq

!--------------------------------------------!
!     eigenvalue and occupancy variables     !
!--------------------------------------------!
! number of empty states
integer nempty
! number of first-variational states
integer nstfv
! number of second-variational states
integer nstsv
! smearing type
integer stype
! smearing function description
character(256) sdescr
! smearing width
real(8) swidth
! maximum allowed occupancy (1 or 2)
real(8) occmax
! convergence tolerance for occupancies
real(8) epsocc
! second-variational occupation number array
real(8), allocatable :: occsv(:,:)
! Fermi energy for second-variational states
real(8) efermi
! density of states at the Fermi energy
real(8) fermidos
! error tolerance for the first-variational eigenvalues
real(8) evaltol
! minimum allowed eigenvalue
real(8) evalmin
! second-variational eigenvalues
real(8), allocatable :: evalsv(:,:)
! tevecsv is .true. if second-variational eigenvectors are calculated
logical tevecsv
! maximum number of k-point and states indices in user-defined list
integer, parameter :: maxkst=20
! number of k-point and states indices in user-defined list
integer nkstlist
! user-defined list of k-point and state indices
integer kstlist(3,maxkst)

!------------------------------!
!     core state variables     !
!------------------------------!
! eigenvalues for core states
real(8), allocatable :: evalcr(:,:)
! radial wavefunctions for core states
real(8), allocatable :: rwfcr(:,:,:,:)
! radial charge density for core states
real(8), allocatable :: rhocr(:,:)

!--------------------------!
!     energy variables     !
!--------------------------!
! eigenvalue sum
real(8) evalsum
! electron kinetic energy
real(8) engykn
! core electron kinetic energy
real(8) engykncr
! nuclear-nuclear energy
real(8) engynn
! electron-nuclear energy
real(8) engyen
! Hartree energy
real(8) engyhar
! Coulomb energy (E_nn + E_en + E_H)
real(8) engycl
! electronic Coulomb potential energy
real(8) engyvcl
! Madelung term
real(8) engymad
! exchange-correlation potential energy
real(8) engyvxc
! exchange-correlation effective field energy
real(8) engybxc
! energy of external global magnetic field
real(8) engybext
! energy of muffin-tin magnetic fields (non-physical)
real(8) engybmt
! exchange energy
real(8) engyx
! correlation energy
real(8) engyc
! compensating background charge energy
real(8) engycbc
! total energy
real(8) engytot

!-------------------------!
!     force variables     !
!-------------------------!
! tforce is .true. if force should be calculated
logical tforce
! tfibs is .true. if the IBS contribution to the force is to be calculated
logical tfibs
! Hellmann-Feynman force on each atom
real(8), allocatable :: forcehf(:,:)
! core correction to force on each atom
real(8), allocatable :: forcecr(:,:)
! IBS core force on each atom
real(8), allocatable :: forceibs(:,:)
! total force on each atom
real(8), allocatable :: forcetot(:,:)
! previous total force on each atom
real(8), allocatable :: forcetp(:,:)
! maximum force magnitude over all atoms
real(8) forcemax
! default step size parameter for structural optimisation
real(8) tau0atm
! step size parameters for each atom
real(8), allocatable :: tauatm(:)

!-------------------------------!
!     convergence variables     !
!-------------------------------!
! maximum number of self-consistent loops
integer maxscl
! current self-consistent loop number
integer iscl
! effective potential convergence tolerance
real(8) epspot
! energy convergence tolerance
real(8) epsengy
! force convergence tolerance
real(8) epsforce

!----------------------------------------------------------!
!     density of states, optics and response variables     !
!----------------------------------------------------------!
! number of energy intervals in the DOS/optics function
integer nwdos
! effective size of k/q-point grid for integrating the Brillouin zone
integer ngrdos
! smoothing level for DOS/optics function
integer nsmdos
! energy interval for DOS/optics function
real(8) wdos(2)
! scissors correction
real(8) scissor
! number of optical matrix components required
integer noptcomp
! required optical matrix components
integer optcomp(3,27)
! usegdft is .true. if the generalised DFT correction is to be used
logical usegdft
! intraband is .true. if the intraband term is to be added to the optical matrix
logical intraband
! lmirep is .true. if the (l,m) band characters should correspond to the
! irreducible representations of the site symmetries
logical lmirep
! spin-quantisation axis in Cartesian coordinates used when plotting the
! spin-resolved DOS (z-axis by default)
real(8) sqados(3)
! q-vector in lattice coordinates for calculating the matrix elements
! < i,k+q | exp(iq.r) | j,k >
real(8) vecql(3)

!-------------------------------------!
!     1D/2D/3D plotting variables     !
!-------------------------------------!
! number of vertices in 1D plot
integer nvp1d
! total number of points in 1D plot
integer npp1d
! vertices in lattice coordinates for 1D plot
real(8), allocatable :: vvlp1d(:,:)
! distance to vertices in 1D plot
real(8), allocatable :: dvp1d(:)
! plot vectors in lattice coordinates for 1D plot
real(8), allocatable :: vplp1d(:,:)
! distance to points in 1D plot
real(8), allocatable :: dpp1d(:)
! corner vectors of 2D plot in lattice coordinates
real(8) vclp2d(3,3)
! grid sizes of 2D plot
integer np2d(2)
! corner vectors of 3D plot in lattice coordinates
real(8) vclp3d(3,4)
! grid sizes of 3D plot
integer np3d(3)
! number of states for plotting Fermi surface
integer nstfsp

!----------------------------------------!
!     OEP and Hartree-Fock variables     !
!----------------------------------------!
! maximum number of core states over all species
integer ncrmax
! maximum number of OEP iterations
integer maxitoep
! initial value and scaling factors for OEP step size
real(8) tauoep(3)
! magnitude of the OEP residual
real(8) resoep
! kinetic matrix elements
complex(8), allocatable :: kinmatc(:,:,:)
! complex versions of the exchange potential and field
complex(8), allocatable :: zvxmt(:,:,:)
complex(8), allocatable :: zvxir(:)
complex(8), allocatable :: zbxmt(:,:,:,:)
complex(8), allocatable :: zbxir(:,:)

!-------------------------!
!     LDA+U variables     !
!-------------------------!
! type of LDA+U to use (0: none)
integer ldapu
! maximum angular momentum
integer, parameter :: lmaxlu=3
integer, parameter :: lmmaxlu=(lmaxlu+1)**2
! angular momentum for each species
integer llu(maxspecies)
! U and J values for each species
real(8) ujlu(2,maxspecies)
! LDA+U density matrix
complex(8), allocatable :: dmatlu(:,:,:,:,:)
! LDA+U potential matrix in (l,m) basis
complex(8), allocatable :: vmatlu(:,:,:,:,:)
! LDA+U energy for each atom
real(8), allocatable :: engyalu(:)
! interpolation constant alpha for each atom (PRB 67, 153106 (2003))
real(8), allocatable :: alphalu(:)
! energy from the LDA+U correction
real(8) engylu

!--------------------------!
!     phonon variables     !
!--------------------------!
! number of primitive unit cells in phonon supercell
integer nphcell
! Cartesian offset vectors for each primitive cell in the supercell
real(8) vphcell(3,maxatoms)
! phonon displacement distance
real(8) deltaph
! original lattice vectors
real(8) avec0(3,3)
! original inverse of lattice vector matrix
real(8) ainv0(3,3)
! original number of atoms
integer natoms0(maxspecies)
integer natmtot0
! original atomic positions in Cartesian coordinates
real(8) atposc0(3,maxatoms,maxspecies)
! original G-vector grid sizes
integer ngrid0(3)
integer ngrtot0
! original effective potentials
real(8), allocatable :: veffmt0(:,:,:)
real(8), allocatable :: veffir0(:)
! number of vectors for writing out frequencies and eigenvectors
integer nphwrt
! vectors in lattice coordinates for writing out frequencies and eigenvectors
real(8), allocatable :: vqlwrt(:,:)
! Coulomb pseudopotential
real(8) mustar

!-------------------------------------------------------------!
!     reduced density matrix functional (RDMFT) variables     !
!-------------------------------------------------------------!
! non-local matrix elements for varying occupation numbers
real(8), allocatable :: vnlrdm(:,:,:,:)
! Coulomb potential matrix elements
complex(8), allocatable :: vclmat(:,:,:)
! derivative of kinetic energy w.r.t. natural orbital coefficients
complex(8), allocatable :: dkdc(:,:,:)
! step size for occupation numbers
real(8) taurdmn
! step size for natural orbital coefficients
real(8) taurdmc
! xc functional
integer rdmxctype
! maximum number of self-consistent loops
integer rdmmaxscl
! maximum number of iterations for occupation number optimisation
integer maxitn
! maximum number of iteration for natural orbital optimisation
integer maxitc
! exponent for the functional
real(8) rdmalpha
! temperature
real(8) rdmtemp
! entropy
real(8) rdmentrpy

!--------------------------!
!     timing variables     !
!--------------------------!
! initialisation
real(8) timeinit
! Hamiltonian and overlap matrix set up
real(8) timemat
! first-variational calculation
real(8) timefv
! second-variational calculation
real(8) timesv
! charge density calculation
real(8) timerho
! potential calculation
real(8) timepot
! force calculation
real(8) timefor

!-----------------------------!
!     numerical constants     !
!-----------------------------!
real(8), parameter :: pi=3.1415926535897932385d0
real(8), parameter :: twopi=6.2831853071795864769d0
real(8), parameter :: fourpi=12.566370614359172954d0
! square root of two
real(8), parameter :: sqtwo=1.4142135623730950488d0
! spherical harmonic for l=m=0
real(8), parameter :: y00=0.28209479177387814347d0
! complex constants
complex(8), parameter :: zzero=(0.d0,0.d0)
complex(8), parameter :: zhalf=(0.5d0,0.d0)
complex(8), parameter :: zone=(1.d0,0.d0)
complex(8), parameter :: zi=(0.d0,1.d0)
! array of i**l values
complex(8), allocatable :: zil(:)
! Pauli spin matrices:
! sigma_x = ( 0  1 )   sigma_y = ( 0 -i )   sigma_z = ( 1  0 )
!           ( 1  0 )             ( i  0 )             ( 0 -1 )
complex(8) sigmat(2,2,3)
data sigmat / (0.d0,0.d0), (1.d0,0.d0), (1.d0,0.d0), (0.d0,0.d0), &
              (0.d0,0.d0), (0.d0,1.d0),(0.d0,-1.d0), (0.d0,0.d0), &
              (1.d0,0.d0), (0.d0,0.d0), (0.d0,0.d0),(-1.d0,0.d0) /
! Boltzmann constant in Hartree/kelvin (CODATA 2006)
real(8), parameter :: kboltz=3.166815343d-6

!---------------------------------!
!     miscellaneous variables     !
!---------------------------------!
! code version
integer version(3)
data version / 0,9,224 /
! maximum number of tasks
integer, parameter :: maxtasks=40
! number of tasks
integer ntasks
! task array
integer tasks(maxtasks)
! current task
integer task
! tstop is .true. if STOP file exists
logical tstop
! tlast is .true. if self-consistent loop is on the last iteration
logical tlast
! number of iterations after which STATE.OUT is written
integer nwrite
! filename extension for files generated by gndstate
character(256) filext
! default file extension
data filext / '.OUT' /
! scratch space path
character(256) scrpath
! maximum number of note lines
integer, parameter :: maxnlns=20
! number of note lines
integer notelns
! notes to include in INFO.OUT
character(80) notes(maxnlns)

!-----------------------!
!      MPI parallel     !
!-----------------------!
integer, parameter :: dim1=1
integer, parameter :: dim2=2
integer, parameter :: dim3=3

integer nkptloc
integer nkptnrloc
logical lmpi_grid
data lmpi_grid/.false./
integer mpi_grid(3)
complex(8), allocatable :: evecfvloc(:,:,:,:)
complex(8), allocatable :: evecsvloc(:,:,:)

! dimension for k-points 
integer dim_k
! dimension for q-vectors
integer dim_q
! dimension for interband transitions
integer dim_b


!------------------!
!      addons      !
!------------------!
! coefficient-based represenatation of second-variational states
integer nrfmax
real(8), allocatable :: urf(:,:,:,:)
real(8), allocatable :: urfprod(:,:,:,:)
! number of radial functions for a given l
integer, allocatable :: nrfl(:,:)
integer, allocatable :: lm2l(:)
integer, allocatable :: ias2is(:)
integer, allocatable :: ias2ia(:)
integer, allocatable :: ias2ic(:)
! for local coordinate system
integer natlcs
real(8), allocatable :: lcsrsh(:,:,:)
integer, allocatable :: iatlcs(:)
logical ldensmtrx
real(8) dm_e1,dm_e2
! real <-> complex spherical harmonic transformation
! complex to real
complex(8), allocatable :: rylm(:,:)
! real to complex
complex(8), allocatable :: yrlm(:,:)
! complex to lcs real
complex(8), allocatable :: rylm_lcs(:,:,:)
! lcs real to complex
complex(8), allocatable :: yrlm_lcs(:,:,:)
! band range for task 64
integer bndranglow, bndranghi

complex(8), allocatable :: veffir_zfft(:)

! number of atom classes (non-equivalent atoms)
integer natmcls
! i-th class -> ias mapping
integer, allocatable :: iatmcls(:)



! unit conversion
real(8), parameter :: ha2ev=27.21138386d0
real(8), parameter :: au2ang=0.5291772108d0

!-------------------------!
!     Linear response     !
!-------------------------!
! number of q-vectors
integer nvq0
! list of q-vectors in k-mesh coordinates
integer, allocatable :: ivq0m_list(:,:)
! q-vector in lattice coordinates
real(8) vq0l(3)
! q-vector in Cartesian coordinates
real(8) vq0c(3)
! reduced q-vector in lattice coordinates
real(8) vq0rl(3)
! reduced q-vector in Cartesian coordinates
real(8) vq0rc(3)
! index of G-vector which brings q to first BZ
integer lr_igq0
! first G-shell for matrix elements
integer gshme1
! last G-shell for matrix elements
integer gshme2
! first G-vector for matrix elements
integer gvecme1
! last G-vector for matrix elements
integer gvecme2
! number of G-vectors for matrix elements
integer ngvecme

! number of energy-mesh points
!integer nepts
integer lr_nw
real(8) lr_w0
real(8) lr_w1
real(8) lr_dw
! energy mesh
complex(8), allocatable :: lr_w(:)
!real(8) maxomega
!real(8) domega
real(8) lr_eta


real(8) lr_e1,lr_e2
! type of linear response calculation
!   0 : charge response
!   1 : magnetic response
integer lrtype
real(8) lr_min_e12

! G+q vectors in Cart.coord.
real(8), allocatable :: lr_vgq0c(:,:)
! length of G+q vectors
real(8), allocatable :: lr_gq0(:)
! theta and phi angles of G+q vectors
real(8), allocatable :: lr_tpgq0(:,:)
! sperical harmonics of G+q vectors
complex(8), allocatable :: lr_ylmgq0(:,:)
! structure factor for G+q vectors
complex(8), allocatable :: lr_sfacgq0(:,:)

! number of matrix elements <nk|e^{-i(G+q)x}|n'k+q> in the Bloch basis
!  for a given k-point
integer, allocatable :: nmegqblh(:)
integer, allocatable :: nmegqblhloc(:,:)
! maximum number of matrix elements <nk|e^{-i(G+q)x}|n'k+q> over all k-points
integer nmegqblhmax
integer nmegqblhlocmax
! matrix elements <nk|e^{-i(G+q)x}|n'k+q> in the Bloch basis
!   1-st index : G-vector
!   2-nd index : global index of pair of bands (n,n')
!   3-rd index : k-point
complex(8), allocatable :: megqblh(:,:,:)
! matrix elements <nk|e^{-i(G+q)x}|n'k+q> in the Bloch basis
!   1-st index : global index of pair of bands (n,n')
!   2-nd index : G-vector
!   3-rd index : k-point
complex(8), allocatable :: megqblh2(:,:)
! pair of bands (n,n') for matrix elements <nk|e^{-i(G+q)x}|n'k+q> by global index
!   1-st index :  1 -> n
!                 2 -> n'
!   2-nd index : global index of pair of bands (n,n')
!   3-rd index : k-point
integer, allocatable :: bmegqblh(:,:,:)

logical megqwan_afm
data megqwan_afm/.false./

integer nmegqwanmax
integer nmegqwan
integer megqwan_tlim(2,3)
integer, allocatable :: imegqwan(:,:)
integer, allocatable :: idxmegqwan(:,:,:,:,:)
complex(8), allocatable :: megqwan(:,:)

integer nmegqblhwanmax
integer, allocatable :: nmegqblhwan(:)
integer, allocatable :: imegqblhwan(:,:)

complex(8), allocatable :: wann_cc(:,:,:)
complex(8), allocatable :: wann_cc2(:,:)


integer ngntujumax
integer, allocatable :: ngntuju(:,:)
integer(2), allocatable :: igntuju(:,:,:,:)
complex(8), allocatable :: gntuju(:,:,:)




! array for k and k+q stuff
!  1-st index: index of k-point in BZ
!  2-nd index: 1: index of k'=k+q-K
!              2: index of K-vector which brings k+q to first BZ
integer, allocatable :: idxkq(:,:)
real(8) fxca0
real(8) fxca1
integer nfxca
integer fxctype

! high-level switch: solve scalar equation for chi
logical scalar_chi
data scalar_chi/.false./
! high-level switch: split file with matrix elements over k-points
logical split_megq_file
data split_megq_file/.false./
! high-level switch:: read files in parallel
logical parallel_read
data parallel_read/.true./
! high-level switch:: write files in parallel (where it is possible)
logical parallel_write
data parallel_write/.true./
! high-level switch: compute chi0 and chi in Wannier functions basis
logical wannier_chi0_chi 
data wannier_chi0_chi/.false./
! low level switch: compute matrix elements of e^{i(G+q)x} in the basis of
!   Wannier functions; depends on crpa and wannier_chi0_chi
logical wannier_megq
! low-level switch: write or not file with matrix elements; depends on task 
logical write_megq_file
! low level switch: compute screened W matrix; depends on crpa
logical screened_w
data screened_w/.false./
logical screened_u
data screened_u/.false./
logical write_chi0_file

real(8) megqwan_maxdist

logical crpa
real(8) crpa_e1,crpa_e2
! 0: W is computed from "symmetrized" dielectric function
! 1: W is computed from chi
! 2: W is computed from chi but without bare Coulomb part
integer crpa_scrn

integer, allocatable :: spinor_ud(:,:,:)

! indices of response functions in global array f_response(:,:,:)
integer, parameter :: f_chi0                 = 1
integer, parameter :: f_chi                  = 2
integer, parameter :: f_chi_scalar           = 3
integer, parameter :: f_chi_pseudo_scalar    = 4
integer, parameter :: f_epsilon_matrix_GqGq  = 5
integer, parameter :: f_epsilon_scalar_GqGq  = 6
integer, parameter :: f_inv_epsilon_inv_GqGq = 7
integer, parameter :: f_epsilon_eff          = 8
integer, parameter :: f_epsilon_eff_scalar   = 9
integer, parameter :: f_sigma                = 10
integer, parameter :: f_sigma_scalar         = 11
integer, parameter :: f_loss                 = 12
integer, parameter :: f_loss_scalar          = 13
integer, parameter :: f_chi0_wann_full       = 14
integer, parameter :: f_chi0_wann            = 15
integer, parameter :: f_chi_wann             = 16
integer, parameter :: f_epsilon_eff_wann     = 17
integer, parameter :: f_sigma_wann           = 18
integer, parameter :: f_loss_wann            = 19

integer, parameter :: nf_response            = 19
complex(8), allocatable :: f_response(:,:,:)

integer maxtr_uscrn
integer ntr_uscrn
integer, allocatable :: vtl_uscrn(:,:)
integer, allocatable :: ivtit_uscrn(:,:,:)
complex(8), allocatable :: uscrnwan(:,:,:,:)
complex(8), allocatable :: ubarewan(:,:,:)









!------------------!
!     Wannier      !
!------------------!
logical wannier
integer wann_natom
integer wann_norbgrp
integer wann_ntype
!logical wann_use_eint
logical wann_add_poco
integer, allocatable :: wann_norb(:)
integer, allocatable :: wann_iorb(:,:,:)
integer, allocatable :: wann_iprj(:,:)
real(8), allocatable :: wann_eint(:,:)
!integer, allocatable :: wann_nint(:,:)
real(8), allocatable :: wann_v(:)

integer nwann
integer, allocatable :: iwann(:,:)
integer, allocatable :: nwannias(:)
  
! expansion coefficients of Wannier functions over spinor Bloch eigen-functions  
complex(8), allocatable :: wann_c(:,:,:)
! Bloch-sums of WF
complex(8), allocatable :: wann_unkmt(:,:,:,:,:,:)
complex(8), allocatable :: wann_unkit(:,:,:,:)

! H(k) in WF basis
complex(8), allocatable :: wann_h(:,:,:)
! e(k) of WF H(k) (required for band-sctructure plot only)
real(8), allocatable :: wann_e(:,:)
! momentum operator in WF basis
complex(8), allocatable :: wann_p(:,:,:,:)

real(8), allocatable :: wann_ene(:)
real(8), allocatable :: wann_occ(:)

complex(8), allocatable :: wf_v_mtrx(:,:,:,:,:)

real(8) zero3d(3)
real(8) bound3d(3,3)
integer nrxyz(3)
integer nwfplot
integer firstwf
logical wannier_lc
integer nwann_lc
integer, allocatable :: wann_iorb_lc(:,:,:)
real(8), allocatable :: wann_iorb_lcc(:,:)

integer nwann_h
integer, allocatable :: iwann_h(:)

logical wannier_soft_eint
real(8) wannier_soft_eint_width
real(8) wannier_soft_eint_e1
real(8) wannier_soft_eint_e2
real(8) wannier_min_prjao

logical ldisentangle

!----------------!
!      timer     !
!----------------!
integer, parameter :: t_iter_tot=2
integer, parameter :: t_init=10

integer, parameter :: t_seceqn=18
integer, parameter :: t_seceqnfv=19
integer, parameter :: t_seceqnfv_setup=20
integer, parameter :: t_seceqnfv_setup_h=21
integer, parameter :: t_seceqnfv_setup_h_mt=22
integer, parameter :: t_seceqnfv_setup_h_it=23
integer, parameter :: t_seceqnfv_setup_o=24
integer, parameter :: t_seceqnfv_setup_o_mt=25
integer, parameter :: t_seceqnfv_setup_o_it=26
integer, parameter :: t_seceqnfv_diag=27

integer, parameter :: t_seceqnsv=30
integer, parameter :: t_svhmlt_setup=31
integer, parameter :: t_svhmlt_diag=32
integer, parameter :: t_svhmlt_tot=33

integer, parameter :: t_apw_rad=40
integer, parameter :: t_rho_mag_sum=41
integer, parameter :: t_rho_mag_sym=42
integer, parameter :: t_rho_mag_tot=43
integer, parameter :: t_pot=44
integer, parameter :: t_dmat=45





logical wproc

! number of nearest neighbours for each atom
integer, allocatable :: nnghbr(:)
! list of nearest neighbours
integer, allocatable :: inghbr(:,:,:)


!-----------------------!
!      constrain LDA    !
!-----------------------!
logical clda
logical clda_rlmlcs
integer clda_norb
integer clda_iat(2)
integer clda_ispn(2)
integer, allocatable :: clda_iorb(:,:)
real(8), allocatable :: clda_vorb(:,:)

end module

