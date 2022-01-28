# Runtime options file for Phantom, written 18/02/2019 18:16:28.7
# Options not present assume their default values
# This file is updated automatically after a full dump

# job name
             logfile =   polar01.log    ! file to which output is directed
            dumpfile =   polar_00000    ! dump file to start from

# options controlling run time and input/output
                tmax =  174.846685    ! end time
               dtmax =  2.5  ! time between dumps
                nmax =          -1    ! maximum number of timesteps (0=just get derivs and stop)
                nout =          -1    ! number of steps between dumps (-ve=ignore)
           nmaxdumps =           1    ! stop after n full dumps (-ve=ignore)
            twallmax =      000:00    ! maximum wall time (hhh:mm, 000:00=ignore)
           dtwallmax =      012:00    ! maximum wall time between dumps (hhh:mm, 000:00=ignore)
           nfulldump =          1    ! full dump every n dumps
            iverbose =           0    ! verboseness of log (-1=quiet 0=default 1=allsteps 2=debug 5=max)

# options controlling accuracy
              C_cour =       0.300    ! Courant number
             C_force =       0.250    ! dt_force number
                tolv =   1.000E-02    ! tolerance on v iterations in timestepping
               hfact =       1.200    ! h in units of particle spacing [h = hfact(m/rho)^(1/3)]
                tolh =   1.000E-04    ! tolerance on h-rho iterations

# options controlling hydrodynamics, artificial dissipation
               alpha =  0.139438999  ! art. viscosity parameter
                beta =       2.000    ! beta viscosity
        avdecayconst =       0.100    ! decay time constant for viscosity switches

# options controlling damping
               idamp =           0    ! artificial damping of velocities (0=off, 1=constant, 2=star)

# options controlling equation of state
                ieos =           3    ! eqn of state (1=isoth;2=adiab;3=locally iso;8=barotropic)
                  mu =       2.381    ! mean molecular weight

# options controlling sink particles
     h_soft_sinksink =       0.000    ! softening length between sink particles
               f_acc =       0.800    ! particles < f_acc*h_acc accreted without checks

# options relating to external forces
      iexternalforce =           0    ! 1=star,2=coro,3=bina,4=prdr,5=toru,6=toys,7=exte,8=spir,9=Lens,10=neut,11=Eins,

# options controlling physical viscosity
           irealvisc =           0    ! physical viscosity type (0=none,1=const,2=Shakura/Sunyaev)
          shearparam =       0.100    ! magnitude of shear viscosity (irealvisc=1) or alpha_SS (irealvisc=2)
            bulkvisc =       0.000    ! magnitude of bulk viscosity
