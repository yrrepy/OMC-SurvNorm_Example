# https://info.ornl.gov/sites/publications/Files/Pub147442.pdf

#!/bin/bash
#SBATCH -J  ORCS-R2S                    # Job name
#SBATCH -p x                            # Optional selection of Node ("partition")                                                           
#SBATCH --nodes=1                       # -N;  number of nodes on which to run 
#SBATCH --ntasks=56                     # -n;  number of tasks to run = Total Number of MPI ranks+1 (MCNP Master)
#SBATCH --ntasks-per-node=56            #      number of MPI tasks to invoke on each node
#SBATCH --threads-per-core=1            #      Lock threads to Cores
#SBATCH --exclusive                                                                                                                                              
#SBATCH --no-requeue
#SBATCH --output=job_%j.log             # Standard output and error log 
#SBATCH -vv


# MPI Settings
# export OMP_PROC_BIND=TRUE
export MV2_ENABLE_AFFINITY=0

# Determine number of Cores available on Node. Is divided by 2 assuming there are 2 NUMA spaces. Is subtracted by 1 for MCNP MPI Master task
OMP1=$(lscpu | grep -m1  'CPU(s):'  | awk '{print ($2)}')
OMP2=$(lscpu | grep -m1  'CPU(s):'  | awk '{print ($2/2-1)}')


chmod 777 * 
#
#
# NOTE: need 4 inputs (neutron transport, photon transport, neutron advantg,
# photon advantg) plus any optional items (like quadrature files for Denovo)
#
export  SRCDIR="`pwd`"
export EXECDIR="`pwd`/run1"
mkdir $EXECDIR
cd    $EXECDIR
echo Copying $SRCDIR files to $EXECDIR...
cp           $SRCDIR/* .
#

#
# This script is designed to run on 1 nodes / 56 processors per node
#
# NAGSS (runs X copies of the program on each node on shared memory)
export NAGSS='srun       --mpi=pmix_v3 -n 1 ~/Codes/advantg/src/msx-1.1.0/nagss/nagss'
export NAGSS_mcpl='srun  --mpi=pmix_v3 -n 1 ~/Codes/advantg/src/msx-1.1.0/nagss-mcpl_IsoFix/nagss'
# ADVANTG with threading
export ADVANTG='~/Codes/advantg/packages/advantg/bin/advantg  -v -f -t'
# MSX Utilities
export MSX_LOAD='~/Codes/advantg/packages/msx/bin/msx_load'
export     MSX_ACTIVATE='srun -vv --mpi=pmix_v3       ~/Codes/advantg/packages/msx/bin/msx_activate'
export   MSX_GEN_KERNEL='srun -vv --mpi=pmix_v3       ~/Codes/advantg/packages/msx/bin/msx_gen_kernel'
export MSX_APPLY_KERNEL='srun -vv --mpi=pmix_v3       ~/Codes/advantg/packages/msx/bin/msx_apply_kernel'
export MSX_POST='srun -vv                       -n 1  ~/Codes/advantg/packages/msx/bin/msx_post'
# MCNP5 with ORNL-TN
export MCNP5BASEN='srun -vv --mpi=pmix_v3 -n 1  ~/Codes/MCNP630/bin/mcnp-6.3.0-Linux-MPICH/bin/mcnp6.mpich'
# MCNP5 with ORNL-TN and NAGSS source routine
export MCNP5BASEG='srun -vv --mpi=pmix_v3 -n 1  ~/Codes/advantg/packages/ornl-tn/bin/mcnp5-NAGSS-source'
#
# step descriptions:
# step 1:  msx_gen_kernel           - generate activation kernel
# step 2:  advantg                  - generate photon adjoints with advantg/denovo
# step 3:  msx_load                 - load material data and photon adjoints from advantg output
# step 4:  advantg/msx_apply_kernel - calculate neutron adjoint source using steps 1 & 3, place it in advantg directory
# step 5:  advantg                  - generate a neutron wwinp file
# step 6:  mcnp                     - use wwinp from step 5 & generate neutron fluxes in a meshtal file
# step 7:  MSX                      - steps to generate a gamma activation source
# step 7a: msx_load                 - load material data and neutron fluxes from the mcnp meshtal file
# step 7b: msx_activate             - activation calculation; calculate number densities
# step 7c: msx_post                 - calculate gamma sources
# step 8:  advantg                  - generate gamma weight windows
# step 9:  nagss                    - generate MCNP source
# step 10: mcnp                     - generate gamma results
#
# switches to control step execution
 step1exec=true
 step2exec=true
 step3exec=true
 step4exec=true
 step5exec=true
 step6exec=true
 step7exec=true
 step8exec=true
 step9exec=true
step10exec=true
# substeps inside step 7
step7aexec=true
step7bexec=true
step7cexec=true


# switches to control whether NAGSS is executed for production of individual nuclide phase-spaces
nagss_indiv_nucl=false


# ******************************************************************************
# step 1: generate the kernel
# NOTE: neutron energy descending in eV
# gamma energy descending in MeV
#
if [ "$step1exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 1"
echo "******************************************************************************"
cat << eof > input_gen_kernel
neutron_group_bounds=(1.41907E+07,1.34986E+07,1.22140E+07,1.10517E+07,1.00000E+07,
9.04837E+06,8.18731E+06,7.40818E+06,6.70320E+06,6.06531E+06,
5.48812E+06,4.96585E+06,4.49329E+06,4.06570E+06,3.67879E+06,
3.32871E+06,3.01194E+06,2.72532E+06,2.46597E+06,1.82684E+06,
1.35335E+06,1.00259E+06,7.42736E+05,5.50232E+05,4.07622E+05,
3.01974E+05,2.23708E+05,1.65727E+05,1.22773E+05,6.73795E+04,
3.18278E+04,1.50344E+04,7.10174E+03,3.35463E+03,1.58461E+03,
7.48518E+02,3.53575E+02,1.67017E+02,7.88932E+01,3.72665E+01,
1.76035E+01,8.31529E+00,3.92786E+00,1.85539E+00,8.76425E-01,
4.13994E-01,1.00001E-05)
gamma_group_bounds=(1.4000E+01,1.2000E+01,1.0000E+01,8.0000E+00,7.5000E+00,
7.0000E+00,6.5000E+00,6.0000E+00,5.5000E+00,5.0000E+00,
4.5000E+00,4.0000E+00,3.5000E+00,3.0000E+00,2.5000E+00,
2.0000E+00,1.5000E+00,1.0000E+00,4.0000E-01,2.0000E-01,
1.0000E-01,1.0000E-02)
# Sample EOL 5 hour irradiation, 12-hour decay
#
time_step_factor = 60 # time_steps given in minutes
time_steps = (
  300,  #  5 hour irradiation
   720) # 12 hour decay
flux_factor = 1.0
flux_step_factors = (
 7.64264E+12,
 0) # 1 Treatment

eof
$MSX_GEN_KERNEL  --silent  input_gen_kernel

fi
# ******************************************************************************
# step 2: generate photon adjoint

if [ "$step2exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 2"
echo "******************************************************************************"

# Setup and run ADVANTG
cat << eof2 > input_photon_adjoint
method dx
dx_adjoint True
dx_forward False

anisn_library 27n19g
mcnp_input mcnp_inp_G_adv
mcnp_sb_type none
mcnp_tallies 404

mcnp_min_source_samples 1e6
mcnp_max_source_samples 1e8
mcnp_target_source_density 1e5
mcnp_min_rays_per_face 100

mesh_x -195 195
mesh_x_ints 195

mesh_y -140 180
mesh_y_ints 160

mesh_z -220 10
mesh_z_ints 115

denovo_quadrature qr
denovo_quad_num_azi_vec 1 2 3 4 5 6 7 8
denovo_quad_num_polar 8

denovo_pn_order 3
denovo_tolerance 1E-5

denovo_transport_correction cesaro

denovo_x_blocks 7
denovo_y_blocks 8
eof2

$ADVANTG $OMP1 input_photon_adjoint
fi
# ******************************************************************************
# step 3: execute msx_load on the ADVANTG output
if [ "$step3exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 3"
echo "******************************************************************************"

cat << eof3 > input_msx_load_adv.py
SetHDF5File("msx_adjoint.h5")
SetAdvantgRunDirectory("./")
LoadAdvantgMatls()
LoadAdvantgFlux("adj","p")
eof3

$MSX_LOAD input_msx_load_adv.py

fi
# *****************************************************************************************
# step 4: apply kernel to generate adjoint neutron source
if [ "$step4exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 4"
echo "******************************************************************************"

if [ ! -d advantg_neutron ]
then
 mkdir advantg_neutron
fi

cd advantg_neutron
ln -s ../mcnp_inp_N_adv .
ln -s ../config .
cat << eof5 > input_advantg_n_v1
method fwcadis

fwcadis_spatial_treatment global

anisn_library 27n19g
anisn_upscatter true

mcnp_input mcnp_inp_N_adv
mcnp_sb_type none
mcnp_tallies 4

mcnp_min_source_samples    1e6
mcnp_max_source_samples    1e9
mcnp_target_source_density 1e5
mcnp_min_rays_per_face     100
mcnp_ww_collapse_factor      1

mesh_x -195 195
mesh_x_ints 195

mesh_y -140 180
mesh_y_ints 160

mesh_z -220 10
mesh_z_ints 115

denovo_quadrature qr
denovo_quad_num_azi_vec 1 2 3 4 5 6 7 8
denovo_quad_num_polar 8

denovo_pn_order 3
denovo_tolerance 1E-4
denovo_max_iterations 0

denovo_transport_correction cesaro

denovo_x_blocks 7
denovo_y_blocks 8
mcnp_lost_rays 1000

mcnp_mxspln 20
mcnp_ww_ratio 5

eof5

# run the first ADVANTG execution
$ADVANTG $OMP1 input_advantg_n_v1

# Back up to main execdir
cd ..

cat << eof4 > input_apply_kernel
hdf5_input = "./msx_adjoint.h5"
kernel_input = "./msx_kernel.dat"
transpose = true
denovo_hdf5_input = "./advantg_neutron/fwcadis_adj_solution/denovo-adjoint.inp.h5"
denovo_hdf5_output = "denovo-adjoint.inp.h5"
# Sample EOL 5 hour irradiation, 12-hour decay
#
time_step_factor = 60 # time_steps given in minutes
time_steps = (
  300,  #  5 hour irradiation
   720) # 12 hour decay
flux_factor = 1.0
flux_step_factors = (
 7.64264E+12,
 0) # 1 Treatment


eof4

echo Applying kernel
$MSX_APPLY_KERNEL  --silent  input_apply_kernel

cp denovo-adjoint.inp.h5 ./advantg_neutron/fwcadis_adj_solution/denovo-adjoint.inp.h5

fi
# ***********************************************************************************************
# step 5: make a neutron wwinp file
if [ "$step5exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 5"
echo "******************************************************************************"

cd advantg_neutron

# go into fwcadis_adj_solution
cd fwcadis_adj_solution

# replace max_iterations 0 in omnibus.inp.omn
perl -pi -e 's/max_iterations 0/max_iterations 100/g;' omnibus.inp.omn
perl -pi -e 's/\"max_itr\" type=\"int\" value=\"0\"/\"max_itr\" type=\"int\" value=\"100\"/g;' omnibus.inp.xml

perl -pi -e 's/\<Parameter name=\"scale_rev\"/\<Parameter name=\"num_threads\" type=\"int\" value=\"1\" \/\>\<Parameter name=\"scale_rev\"/g;' omnibus.inp.xml
# run Denovo with the kernel sources
srun -vv --mpi=pmix_v3   ~/Codes/advantg/packages/exnihilo/bin/omnibus omnibus.inp.xml

# back up to the advantg run directory
cd ..

# force ADVANTG to run with the new fwcadis_adj_solution
$ADVANTG $OMP1 input_advantg_n_v1

# back up to main exec directory
cd ..

fi
#
# **************************************************************************************************
# step 6: run MCNP to generate neutron meshtal
# NOTE: run exterior script for this step
if [ "$step6exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 6"
echo "******************************************************************************"

if [ ! -d mcnp_neutron ]
then
 mkdir mcnp_neutron
fi

cd mcnp_neutron
cp ../mcnp_inp_N .

cat   ../advantg_neutron/output/inp_edits.txt >> mcnp_inp_N
ln -s ../advantg_neutron/output/wwinp wwinp_mscadis_neutron


# Execute MCNP Neutron Run
rm -r temp_exec
mkdir temp_exec
cd    temp_exec
ln -s $EXECDIR/mcnp_neutron/wwinp_mscadis_neutron .
mv    $EXECDIR/mcnp_neutron/mcnp_inp_N .


module unload mpi/2021.9.0        # Unload Intel oneAPI MPI (not compatible with srun mpiexec of MCNP)
srun -vv --mpi=pmix_v3 -n 3  ~/Codes/MCNP630/bin/mcnp-6.3.0-Linux-OpenMPI/bin/mcnp6.ompi i=mcnp_inp_N tasks $OMP2 runtpe=trash wwinp=wwinp_mscadis_neutron  
module load mpi/2021.9.0          # Load Intel oneAPI MPI (not compatible with srun mpiexec of MCNP)

mv meshtal $EXECDIR/mcnp_neutron/meshtal
cd         $EXECDIR/mcnp_neutron

cd ..
fi

#
# **************************************************************************************************
# step 7: run MSX (load, activate, post) to generate activation gamma sources
if [ "$step7exec" = true ]
then
if [ "$step7aexec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 7a"
echo "******************************************************************************"
if [ ! -d advantg_source ]
then
 mkdir advantg_source
fi
cd advantg_source
cp -p ../mcnp_inp_G_adv .
ln -s ~/Codes/advantg/data/advantg/200n47g* .
mkdir model
cp ../model/runtpe model/
cat << eof20 > input_dx
method dx

dx_adjoint False
dx_forward False

anisn_library 200n47g
mcnp_input mcnp_inp_G_adv
mcnp_sb_type none
mcnp_tallies 904

mcnp_min_source_samples 1e9
mcnp_max_source_samples 5e10
mcnp_target_source_density 1e8
mcnp_min_rays_per_face 20000

mesh_x -195 195
mesh_x_ints 195

mesh_y -140 180
mesh_y_ints 160

mesh_z -220 10
mesh_z_ints 115

# mcnp_unfolding_origin 600.0 10.0 60.0
# mcnp_unfolding_safe True

denovo_quadrature qr
denovo_quad_num_azi_vec 1 2 3 4 5 6 7 8
denovo_quad_num_polar 8

denovo_pn_order  5
denovo_tolerance 1E-5

denovo_transport_correction cesaro

denovo_x_blocks 7
denovo_y_blocks 8

eof20

$ADVANTG $OMP1 -v input_dx
cd ..

cat << eof7a > input_msx_load_NAGSS.py
SetHDF5File("msx_activate_NAGSS.h5")
SetAdvantgRunDirectory("./advantg_source/")
LoadAdvantgMatls()
SetMeshtalFile("./mcnp_neutron/meshtal")
LoadMeshtalFlux(4)

eof7a

$MSX_LOAD input_msx_load_NAGSS.py
fi

if [ "$step7bexec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 7b"
echo "******************************************************************************"


# ------------------------
# Activation at EOL
# ------------------------
mkdir EOL && cd EOL

for i in 0 0.2 12; do 
mkdir EOL_$i-hrs && cd EOL_$i-hrs 

echo ' '
echo '---------------------------------------------'
echo 'MSX Origen Activation at EOL + ' $i ' hours'
echo '---------------------------------------------'
echo ' '
cat << eof7b > input_msx_activate_EOL_$i-mins_NAGSS
hdf5_input  = "../../msx_activate_NAGSS.h5"
hdf5_output = "numdens_EOL_$i-mins_NAGSS.h5"

# Sample EOL 5 hour irradiation, X-hour decay
#
time_step_factor = 3600 # time_steps given in hours
time_steps = (
   5,  #  5 hour irradiation
   $i) # X hour decay
flux_factor = 1.0
flux_step_factors = (
 7.64264E+12,
 0) # 1 Treatment

min_number_density = 1e-18

eof7b

$MSX_ACTIVATE  --silent  input_msx_activate_EOL_$i-mins_NAGSS 





echo ' '
echo '---------------------------------------------'
echo 'MSX Post at EOL + ' $i ' minutes'
echo '---------------------------------------------'
echo ' '
cat << eof7c > input_msx_post_EOL_$i-mins_NAGSS.py
from __future__ import print_function
import os
infile = HDF5File("numdens_EOL_$i-mins_NAGSS.h5","r")

groups =  Groups([1.00000E+01,5.00000E+00
                 ,4.50000E+00,4.00000E+00
                 ,3.50000E+00,3.00000E+00
                 ,2.76000E+00,2.74000E+00
                 ,2.50000E+00,2.12000E+00
                 ,2.10000E+00,2.00000E+00
                 ,1.82000E+00,1.80000E+00
                 ,1.68000E+00,1.66000E+00
                 ,1.38300E+00,1.37000E+00
                 ,1.35000E+00,1.34000E+00
                 ,1.32000E+00,1.30000E+00
                 ,1.28000E+00,1.18000E+00
                 ,1.16000E+00,1.00000E+00
                 ,8.70000E-01,8.60000E-01
                 ,8.50000E-01,8.45000E-01
                 ,8.40000E-01,8.30000E-01
                 ,8.20000E-01,8.15000E-01
                 ,8.05000E-01,8.00000E-01
                 ,7.50000E-01,7.00000E-01
                 ,6.00000E-01,5.20000E-01
                 ,5.00000E-01,4.50000E-01
                 ,4.00000E-01,3.00000E-01
                 ,2.00000E-01,1.50000E-01
                 ,1.00000E-01,7.50000E-02
                 ,7.00000E-02,6.00000E-02
                 ,4.50000E-02,3.00000E-02
                 ,2.00000E-02,1.00000E-02
                 ,1.00000E-03])
print("Number of Gamma Groups: ", groups.num_groups)
print(" ")
print("Gamma Group Bounds:     ", groups.bounds)
print(" ")

nucl =infile.nuclides
print("Nuclides in Activation Inventory:", nucl)
print(" ")


field    = ActivityField(infile)
total    =0

for x in range(0, 195):
  for y in range(0, 160):
    for z in range(0, 115):
       total    =total+field(x,y,z)
remain   =total


# Creating MSX Source for all nuclides
os.mkdir(str('all_nucl'))
os.chdir(str('all_nucl'))
outfile = GammaSourceField(infile,groups)
outfile.write_nagss()
os.chdir("../")

print(" ")
# Creating MSX Source for Individual nuclides
for n in nucl:
#    print("Working on Nuclide= ",n)
    fieldN    = ActivityField(infile,n)
    totalN    =0
    for x in range(0, 195):
      for y in range(0, 160):
        for z in range(0, 115):
           totalN    =totalN+fieldN(x,y,z)
# below is logic to do only for nuclides that are radioactive (create, enter and exec only their directories), for now is 0.1% of activity, should be changed to 0.1% of gamma emissions (as in below comment)
#   if ((GammaSourceField(infile,groups,n))/GammaSourceField(infile,groups))) > 0.001; # if more than 0.1% of gamma emissions
    if ((totalN/total) > 0.001 ):
        remain=remain-totalN
        print(' EOL       Radioactivity of Nuclide ',"{:7d}".format(n),' at t= 5 minutes decay  = ', "{:.2e}".format(totalN),' [Bq]; which is ',"{:4.1f}".format(totalN/total*100),'% of Total Activity')
        os.mkdir(str(n))
        os.chdir(str(n))
        outfile = GammaSourceField(infile,groups,n)
        outfile.write_nagss()
        os.chdir("../")


print(" ")
print("EOL+XX hours decay;      Total Radioactivity at t= XX hours decay  = ", "{:.2e}".format(total)," [Bq]; radioactivity not accounted for in NAGSS Gamma Fields= ", "{:.2e}".format(remain)," or ","{:4.1f}".format(remain/total*100),'% of Total Activity')
print(" ")


eof7c

$MSX_POST input_msx_post_EOL_$i-mins_NAGSS.py

cd ..
done

cd ..

# EOL

fi

if [ "$step7cexec" = true ]
then

echo "******************************************************************************"
echo "                Beginning Step 7c"
echo "******************************************************************************"

fi

fi
#
# **************************************************************************************************
# step 8: run ADVANTG to generate gamma weight windows
if [ "$step8exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 8"
echo "******************************************************************************"

if [ ! -d advantg_gamma ]
then
 mkdir advantg_gamma
fi

cd advantg_gamma

# Link inputs and cross-section library
ln -s ../mcnp_inp_G_adv .
ln -s ~/Codes/advantg/data/advantg/fendl31_46n21g* .
# Copy over the previously generated runtpe to save time
mkdir model
cp ../model/runtpe model/
# Generate the ADVANTG input

cat << eof8 > input_photon_CADIS

method cadis

anisn_library fendl31_46n21g
mcnp_input    mcnp_inp_G_adv
mcnp_sb_type  none
mcnp_tallies  404

mcnp_min_source_samples    1e6
mcnp_max_source_samples    1e8
mcnp_target_source_density 100
mcnp_min_rays_per_face     10
mcnp_ww_collapse_factor     5

mesh_x -195 195
mesh_x_ints 195

mesh_y -140 180
mesh_y_ints 160

mesh_z -220 10
mesh_z_ints 115

denovo_quadrature qr
denovo_quad_num_azi   4
denovo_quad_num_polar 4

denovo_pn_order  5
denovo_tolerance 1E-3

denovo_transport_correction cesaro

denovo_x_blocks 7
denovo_y_blocks 8

eof8

# Run ADVANTG to generate the gamma weight windows
$ADVANTG $OMP1 input_photon_CADIS
cd ..
fi


#
# **************************************************************************************************
# step 9: run NAGSS to generate MCNP source
if [ "$step9exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 9"
echo "******************************************************************************"

# NB; 28 OMP tasks is faster than 56 OMP tasks on a 56 core PC (NUMA limitations)

cat << eof9 > nagss.inp
55
10
20000
28
1
./wwinp_mscadis_gamma
./inp_edits.txt
200000
0
0
eof9

# NAGSS input
# number of energy group files to search for
# number of batches to sample
# number of samples per batch per thread
# number of threads to execute
# number of random MCNP output files
# path to gamma ww
# path to gamma inp_edits (with response value)
# number of sdef point sources if run in sdef mode



# -------------------------
# NAGSS Execution
# -------------------------
cd EOL

for i in 0.2 12; do 
cd EOL_$i-hrs 
echo ' '
echo '-----------------------------'
echo 'NAGSS at EOL + ' $i ' hours'
echo '-----------------------------'
echo ' '
echo ' '


for d in $(ls -d */); do 
echo 'NAGSS working on nuclide: ' ${d%%/}
cd ${d%%/}
# Link needed files
ln -s ../../../advantg_gamma/output/wwinp wwinp_mscadis_gamma
ln -s ../../../advantg_gamma/output/inp_edits.txt .
ln -s ../../../model/runtpe blarg
cp ../../../nagss.inp .

cp  $SRCDIR/*.xml .


# Logic gate to run NAGSS and produce phase-spaces for individual nuclides or not
if [ "$nagss_indiv_nucl" = true ] ||  [ "${d%%/}" = "all_nucl" ]
then
echo ' '
echo '---------------------------------'
echo 'execute NAGSS and write mcpl phase-space source ...'
echo '---------------------------------'
echo ' '
$NAGSS_mcpl -sampleflat > nagss.mcpl.log.out

echo "Gammas per second"
grep "Normalizing source to:"  nagss.mcpl.log.out
echo ' '
echo ' '

# Merge 28 MCPL Files together
# ~/Codes/MCNP_Utils/mcpl-1.6.1/bin/mcpltool --forcemerge  nagss.x28.mcpl nagss.0.mcpl  nagss.1.mcpl  nagss.2.mcpl  nagss.3.mcpl  nagss.4.mcpl  nagss.5.mcpl  nagss.6.mcpl  nagss.7.mcpl  nagss.8.mcpl  nagss.9.mcpl  nagss.10.mcpl  nagss.11.mcpl  nagss.12.mcpl  nagss.13.mcpl  nagss.14.mcpl  nagss.15.mcpl  nagss.16.mcpl  nagss.17.mcpl  nagss.18.mcpl  nagss.19.mcpl  nagss.20.mcpl  nagss.21.mcpl  nagss.22.mcpl  nagss.23.mcpl  nagss.24.mcpl  nagss.25.mcpl  nagss.26.mcpl  nagss.27.mcpl
fi

cd ..
done

cd ..
done
cd ..
# EOL

fi


#
# **************************************************************************************************
# step 10: run MCNP to generate MCNP gamma results
#
if [ "$step10exec" = true ]
then
echo "******************************************************************************"
echo "                Beginning Step 10"
echo "******************************************************************************"

echo "  "
echo "  "
echo "TBD: Photon Weight Windows"
echo "     Further Automation"
echo "     speed-up EOL activation"
echo "     fix-photon advantg tally location"
echo "  "
echo "  "



fi

exit
