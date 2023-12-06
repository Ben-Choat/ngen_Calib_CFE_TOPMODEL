#!/bin/bash
set -x
# bchoat 2023/11/20
# this script is edited to clone from my branch of ngen that I used for calibration
# work with TOPMODEL and CFE.... basically no submodules are updated.


# bchoat 2023/07/19

# used to build ngen in Ubuntu 22.04

# Script builds and test ngen. Define a folder name which will be used for the home 
# directory for the build as well as for labeling a folder where the build and
# test logs will be saved.


#######################
# inputs
#######################


# provide name for folder that will hold this ngen version
# NOTE: this folder is defined relative to the directory in which this file is located/executed.
folder_name="ngen_20231127_calib"

################
# If want to build ngen-cal you need to include a line in the requirements.txt file

# string defining requirements.txt file to use when building venv environment
# rqr_in should be defined relative to the directory in which this script is being execute.
# the script will copy it to $folder_name_ngen
# rqr_in="requirements_20231120.txt"
# rqr_in is included in this repo so that requirements .txt will be used


# define whith pytho version to use (e.g., "3.10"
py_version="3.10"


# directory holding or where to place boost
boostDir=$PWD

#########################################################



# run deactivate and conda deactivate to ensure using clean slate for python environment
deactivate || true
conda deactivate || true

# define starting directory
baseDir=$PWD



#########
# update folder_name_ngen
folder_name_ngen="${folder_name}/ngen"

# make folder to store logs in 
mkdir "logs_${folder_name}"

# define Numpyn location ... I DO NOT THINK THIS IS NECESSARY?
# export Python_NumPy_INCLUDE_DIRS=/home/bchoat/Projects/NWM_NGEN/${folder_name_ngen}/.venv/lib/python3.10/site-packages
# export Python_NumPy_INCLUDE_DIR=/home/bchoat/Projects/NWM_NGEN/${folder_name_ngen}/.venv/lib/python3.10/site-packages


{
	echo "building in $folder_name_ngen"
	# install libraries
	echo -e "\n\ninstalling libraries into bash\n\n"
	sudo apt-get update &&
		sudo apt-get install cmake &&
		sudo apt-get install g++ &&
		sudo apt-get install gfortran &&
		sudo apt-get install "python${py_version}-dev" &&
		sudo apt-get install "python$py_version" &&
		sudo apt-get install libudunits2-dev &&
		sudo apt-get install libnetcdf-dev libnetcdff-dev &&
		sudo apt-get install libnetcdf-c++4-1 libnetcdf-c++4-dev ||
		exit 1
	
	 
	# clone ngen 
	echo -e "\n\ncloning ngen git repo\n\n"
	# git clone https://github.com/noaa-owp/ngen $folder_name_ngen &&
	git clone -b ngen_calibration_archived https://github.com/Ben-Choat/ngen_Calib_CFE_TOPMODEL $folder_name_ngen &&
		cd $folder_name_ngen &&
		# following line should update all submodules to the version specified in repo
 		git submodule update --init --recursive ||
		exit 1


	echo -e "\n\nbuilding ngen extern libraries\n\n"

	echo -e "\nBuild CFE\n"
# 	git submodule update --remote extern/cfe/cfe &&
 	cmake -B extern/cfe/cmake_build -S extern/cfe/cfe -DNGEN=ON && # -DBASE=OFF -DFORCING=OFF \
# 		-DFORCINGPET=OFF -DAETROOTZONE=OFF -DNGEN=ON &&
		make -C extern/cfe/cmake_build ||

	# UPDATING TO INSTRUCTIONS FOUND HERE: https://github.com/NOAA-OWP/cfe/tree/946a0e8b37d858c168bb4e492d113628ab61be0c
# 	cd extern/cfe
#	git clone https://github.com/NOAA-OWP/cfe.git
#	cd cfe
#	git checkout ajk/sft_aet_giuh_merge
#	git clone https://github.com/NOAA-OWP/SoilMoistureProfiles.git smc_coupler # (needed if AETROOTZONE=ON)
#	mkdir build && cd build &&
#	cmake ../ -DBASE=ON &&  # -DNGEN=ON &&
# 	make &&
	cd "${baseDir}/${folder_name_ngen}" ||

		exit 1


	echo -e "\nBuild TOPMODEL\n"
	# replace topmodel repo with my own dev repo
#	cd extern/topmodel/topmodel
# 	git remote add topmodelDev https://github.com/Ben-Choat/topmodel &&
#		git fetch topmodelDev &&
#		git checkout -b topmodelCal topmodelDev/remove-topmodel-output-fromNgen &&

#	cd ../../../ ||
#		exit 1

	cmake -B extern/topmodel/cmake_build -S extern/topmodel &&
		make -C extern/topmodel/cmake_build ||
		exit 1

	echo -e "\nBuild PET\n"

	cmake -B extern/evapotranspiration/cmake_build -S \
			extern/evapotranspiration/evapotranspiration &&
		make -C extern/evapotranspiration/cmake_build || # petbmi -j2 &&, this is not included here: https://github.com/NOAA-OWP/SoilFreezeThaw/blob/master/INSTALL.md
		exit 1

	
	echo -e "\nBuild SLoTH\n"
#	cd extern/sloth && git checkout latest # as shown here: https://github.com/NOAA-OWP/SoilFreezeThaw/blob/master/INSTALL.md
#	git -submodule update --init --recursive
	# editing to match instructions at https://github.com/NOAA-OWP/SLoTH/blob/master/INSTALL.md
#	cd ../../
	cmake -B extern/sloth/cmake_build -S extern/sloth &&
		make -C extern/sloth/cmake_build ||
		exit 1	

	# SoilFreezeThaw
	echo -e "\nbuild SoilFreezeThaw\n"
#	git submodule update --remote extern/SoilFreezeThaw/SoilFreezeThaw &&
	cmake -B extern/SoilFreezeThaw/cmake_build -S extern/SoilFreezeThaw/SoilFreezeThaw/ -DNGEN=ON &&
		make -C extern/SoilFreezeThaw/cmake_build ||
		exit 1

	
	# compile 
	echo -e "\nbuild noah-owp and adding netcfd libraries\n"
	cmake -B extern/noah-owp-modular/cmake_build -S extern/noah-owp-modular \
		-DnetCDF_INCLUDE_DIR=/usr/include/ -DnetCDF_MOD_PATH=/usr/include/ \
		-DnetCDF_FORTRAN_LIB=/usr/lib/x86_64_linux_gnu/libnetcdff.so &&
		make -C extern/noah-owp-modular/cmake_build ||
		exit 1


	echo -e "build iso_c_fortran_bmi" 
	cmake -B extern/iso_c_fortran_bmi/cmake_build -S extern/iso_c_fortran_bmi &&
		make -C extern/iso_c_fortran_bmi/cmake_build ||
		exit 1


	echo -e "\nbuild test_bmi_c\n"
	cmake -B extern/test_bmi_c/cmake_build -S extern/test_bmi_c &&
		make -C extern/test_bmi_c/cmake_build ||
		exit 1
	

	echo -e "\nbuild test_bmi_fortran\n"
	cmake -B extern/test_bmi_fortran/cmake_build -S extern/test_bmi_fortran &&
		make -C extern/test_bmi_fortran/cmake_build ||
		exit 1


	# get boost library if not already stored in project folder
	echo -e "\n\ninstalling boost if needed\n\n"
	if [ ! -d "${boostDir}/boost_1_77_0" ]; then
		wget -O boost_1_77_0.tar.gz \
			https://boostorg.jfrog.io/artifactory/main/release/1.77.0/source/boost_1_77_0.tar.gz
		tar xzvf boost_1_77_0.tar.gz ||
		exit 1
	fi


	
	# create python virtual environment
	echo -e "\n\ninstalling python libraries w/venv\n\n"
	# install python-venv to get ensurepip
	sudo apt-get install "python${py_version}-venv"
	# get requirements file name and copy to working dir
	rqr_in=$(ls BuildScripts/requirements* | head -2 | tail -1)
	rqr_in=$(basename "$rqr_in")
	# edit requirements file to point to correct hdf5 location
	hdf5Dir=$(find /usr/lib -type d -name hdf5)
	if [ -z "$hdf5Dir" ]; then
		echo -e \
			"\n\n\
			!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! \n\
			WARNING: root hdf5 library not found. \n\
			You may need to manually install tables while pointing \n\
			to correct hdf5 library. For example: \n\
			pip install --install-option='--hdf5=/usr/lib/x86_64-linux-gnu/hdf5' tables==3.7.0 \n\
			!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
	else
		sed -i "/^tables/s|.*|tables==3.7.0 --install-option='--$hdf5Dir'|" "$rqr_in"
		echo -e "\n\nroot hdf5 library found and set as ${hdf5Dir}\n\n"
	fi
	# copy requirments file to $folder_name_ngen
	sudo cp ./BuildScripts/$rqr_in .
	mkdir venv &&
		python$py_version -m venv venv &&
		source venv/bin/activate &&
		pip install -r $rqr_in ||
		exit 1		 
	
	echo -e "\n\nprepending venv directory to PATH\n\n"
# 	echo -e "Set assuming PWD = ${PWD}\n\n"
	export PATH="${PWD}/venv/bin:$PATH"




	# compile ngen -Add boost path -with routing
	cd $baseDir/$folder_name_ngen
	echo -e "\n\nbuilding ngen\n\n"
	cmake -DCMAKE_BUILD_TYPE=Debug -B cmake_build -S . \
		-DBoost_INCLUDE_DIR=$boostDir/boost_1_77_0 \
		-DNGEN_ACTIVATE_PYTHON=ON \
		-DNGEN_ACTIVATE_ROUTING=ON \
		-DBMI_C_LIB_ACTIVE=ON \
		-DBMI_FORTRAN_ACTIVE=ON \
		-DNETCDF_ACTIVE=ON &&
		# -DMPI_ACTIVE=ON && \
		# -DLSTM_TORCH_LIB_ACTIVE=ON && \
		make -j 4 -C cmake_build || # Bchoat changed from 8 to 4 because only 6 processors available w/other running jobs
		exit 1


	##################
        # t-route
        # download and compile


	echo -e "\ncompile t-route\n"
	

        ################
        # Working with newest t-route
        ################

       # first, remove default t-route folder that comes with ngen, it is old
#       cd extern
##      sudo rm -rf t-route
#       mv t-route t-route_ORG
#       # now clone the new t-route
#       git clone --progress --single-branch --branch master http://github.com/NOAA-OWP/t-route.git
#
#       cd t-route
#
#       # compile and install
#       ./compiler.sh

	###############
	# Working with old t-route (version that was already on this machine)
	##############
	# try using old t-route
#	cd $baseDir/$folder_name_ngen/extern/
#	mv t-route t-route_default # stash 'default' folder that comes with ngen
#	ln -s /home/west/git_repositories/ngen_11112022/ngen/extern/t-route
#	# install additional python dependencies (internal to t-route)
#	pip install -e t-route/src/ngen_routing
#	pip install -e t-route/src/nwm_routing
#	cd $baseDir/$folder_name_ngen/extern/t-route/src/python_routing_v02
##	echo -e $PWD
#	./compiler.sh

	###############
	# working with unupdated default version (i.e., version that comes with ngen clone)
	###############
#	cd $basedir/$folder_name_ngen/extern/t-route/src/python_routing_v02/



	#### Ben working here on 2023/11/14
	# just to be explicit, deactivate venv then reactivate. Also, specifiy location of pip
	deactivate || true
	source "$baseDir/$folder_name_ngen"/venv/bin/activate &&

	cd "$baseDir/$folder_name_ngen" &&
	./venv/bin/pip install -e extern/t-route/src/ngen_routing &&
	./venv/bin/pip install -e extern/t-route/src/nwm_routing &&

	cd "$baseDir/$folder_name_ngen"/extern/t-route/src/python_routing_v02 &&
	./compiler.sh ||
	exit 1



	###################	

	cd $baseDir

} | tee -a "logs_${folder_name}/build_log.txt" 2>&1

{	
	echo -e "\n\ntesting ngen bmi installs\n\n"
#	cd $baseDir/$folder_name_ngen
	cd "${baseDir}/${folder_name_ngen}"
	echo -e "PWD: $PWD\n"

	source ./venv/bin/activate

#	./cmake_build/test/test_all &&
	./cmake_build/test/test_bmi_c &&
	./cmake_build/test/test_bmi_fortran &&
	./cmake_build/test/test_bmi_python ||
	exit 1

	###############

	# cfe
#	echo -d "\ntesting cfe\n"
#	cd "${basedir}/${folder_name_ngen}/extern/cfe/cfe"
#	mkdir build && cd build
#	cmake .. -DUNITTEST=ON &&
#	make && cd .. &&
#	cd test && ./run_unittest.sh ||
#	exit 1

	# cfe NEWEST (Test is build when cfe is build)
#	cd "${baseDir}/${folder_name_ngen}/extern/cfe/cfe/"
#	./run_cfe.sh

	#############################

	# t-route
#	echo -e "\n\ntesting t-route\n\n"
#	source venv/bin/activate
#	cd extern/t-route/test/LowerColorado_TX
#	python -m nwm_routing -f test_AnA.yaml


} | tee -a "logs_${folder_name}/test_log.txt" 2>&1

# copy build_ngen.sh and requirements.txt files to build folder
#	cd $baseDir/$folder_name
#	echo -e "${baseDir}/${folder_name_ngen}"
echo -e "PWD: $PWD\n"
# this folder already in the new repo
rm "$folder_name_ngen/$rqr_in"
# mkdir "${baseDir}/${folder_name}/BuildScripts" &&
#	mv "${baseDir}/${folder_name_ngen}/${rqr_in}" "${baseDir}/${folder_name}/BuildScripts" &&
#	cp "${baseDir}/build_ngen.sh" "${baseDir}/${folder_name}/BuildScripts" ||
# 	exit 1

# move logs to new build
mv "logs_${folder_name}" $folder_name ||
	exit 1

