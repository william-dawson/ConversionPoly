!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!> In this example, I will show how to convert a CheSS like segmented
!! csr matrix into the NTPoly format, and back again.
PROGRAM ConversionExample
  USE ConversionModule, ONLY : NTPolyToSeg, SegToNTPoly
  USE dictionaries, ONLY : dictionary, dict_free
  USE Futile
  USE FakeChessModule, ONLY : SegMat_t
  USE ProcessGridModule, ONLY : ConstructProcessGrid, DestructProcessGrid
  USE PSMatrixModule, ONLY : Matrix_ps, CopyMatrix, PrintMatrix
  USE yaml_parse, ONLY : yaml_cl_parse, yaml_cl_parse_null, &
       & yaml_cl_parse_cmd_line, yaml_cl_parse_free, yaml_cl_parse_option
  USE TripletListModule, ONLY : TripletList_r
  USE MPI
  IMPLICIT NONE
  !! Calculation Parameters
  TYPE(dictionary), POINTER :: options
  TYPE(yaml_cl_parse) :: parser
  INTEGER :: MatrixSize
  !! The hamiltonian to convert, which is stored on every process.
  TYPE(SegMat_t) :: Hamiltonian
  !! The density matrix, which is divided by columns.
  TYPE(SegMat_t) :: Density
  !! The NTPoly Hamiltonian
  TYPE(Matrix_ps) :: NTHamiltonian
  !! The NTPoly Density Matrix
  TYPE(Matrix_ps) :: NTDensity
  !! Parallel information
  INTEGER :: num_procs, my_rank
  INTEGER :: start_col, end_col, cols_per_proc
  INTEGER :: ierr
  INTEGER :: provided

  !! Init
  CALL MPI_Init_thread(MPI_THREAD_SERIALIZED, provided, ierr)
  CALL f_lib_initialize()

  !! Command line options
  parser=yaml_cl_parse_null()
  CALL yaml_cl_parse_option(parser,'matrix_size','4','Size of the matrix')
  CALL yaml_cl_parse_cmd_line(parser,args=options)
  CALL yaml_cl_parse_free(parser)

  !! Parallel setup
  CALL InitParallel

  !! The Hamiltonian is a random matrix to start
  MatrixSize = options//'matrix_size'
  Hamiltonian = SegMat_t(MatrixSize, MatrixSize)
  CALL Hamiltonian%FillRandom()
  IF (my_rank .EQ. 0) THEN
     CALL Hamiltonian%print
  END IF

  !! The density matrix is empty to start, but here we will construct
  !! an empty matrix with a suitable partitioning.
  cols_per_proc = MatrixSize/num_procs
  start_col = cols_per_proc*(my_rank-1) + 1
  end_col = start_col + cols_per_proc - 1
  IF (my_rank .EQ. num_procs) THEN
     end_col = MatrixSize
  END IF
  Density = SegMat_t(MatrixSize, cols_per_proc)

  !! Now we will demonstrate the conversions. First, convert to NTPoly.
  CALL SegToNTPoly(Hamiltonian, NTHamiltonian)
  CALL PrintMatrix(NTHamiltonian)

  !! Replace this Copy with whatever solver operation you wish to perform.
  CALL CopyMatrix(NTHamiltonian, NTDensity)

  !! Now convert back and print.
  CALL NTPolyToSeg(NTDensity, Density, start_col, end_col)

  !! Cleanup
  ! CALL dict_free(options)
  CALL CleanupParallel

CONTAINS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Setup MPI/NTPoly
  SUBROUTINE InitParallel
    !! For this driver program
    CALL MPI_Comm_size(MPI_COMM_WORLD, num_procs, ierr)
    CALL MPI_Comm_rank(MPI_COMM_WORLD, my_rank, ierr)

    !! For NTPoly
    CALL ConstructProcessGrid(MPI_COMM_WORLD)
  END SUBROUTINE InitParallel
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !> Tear down MPI/NTPoly
  SUBROUTINE CleanupParallel
    INTEGER :: ierr
    CALL DestructProcessGrid()
    CALL MPI_Finalize(ierr)
  END SUBROUTINE CleanupParallel
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
END PROGRAM ConversionExample
