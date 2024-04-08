#!/usr/bin/env bash

# CS3223 Assignment 3 
# Script to run experiments using slurm

######## Configure SLURM & PGPORT to appropriate values
SLURM=1  		# SLURM=1 if using slurm; otherwise, SLURM=0
export PGPORT=51234  	# port number for postgres server
######## 

# Load data into relations R and S & create indexes
function load_data ()
{
	echo "Loading data ..."
	echo "Number of tuples in relation R = ${NUM_R_TUPLES}"
	echo "Join factor = ${join_factor}"
	echo "Index configuration = ${index_config}"

	psql -e -v nr=${NUM_R_TUPLES} -v jf=${join_factor} <<EOF
DROP INDEX IF EXISTS ra_idx;
DROP INDEX IF EXISTS sy_idx;
DROP TABLE IF EXISTS r;
DROP TABLE IF EXISTS s;
-- Relation r(a,b,c)
SELECT a, a AS b, trunc(random() * 1000000) as c  INTO r FROM (SELECT * FROM generate_series(1,:nr)) AS temp(a);
-- Relation s(x,y,z)
SELECT x, (x % :nr) + 1 AS y, trunc(random() * 1000000) as z INTO s FROM (SELECT * FROM generate_series(1, :nr * :jf)) AS temp(x);
\q
EOF
}


# Create index if necessary
function create_index ()
{
	echo "create index ..."
	echo "Index configuration = ${index_config}"

	if [ "${index_config}"  = "RS" ]; then
		psql -e -c "CREATE INDEX IF NOT EXISTS ra_idx ON r (a); CREATE INDEX IF NOT EXISTS sy_idx ON s (y);"
	elif [ "${index_config}"  = "R" ]; then
		psql -e -c "CREATE INDEX IF NOT EXISTS ra_idx ON r (a); DROP INDEX IF EXISTS sy_idx;"
	elif [ "${index_config}"  = "S" ]; then
		psql -e -c "CREATE INDEX IF NOT EXISTS sy_idx ON s (y); DROP INDEX IF EXISTS ra_idx;"
	else
		echo "ERROR: invalid index configuration ${index_config}!"
		exit 1
	fi
	psql -e -c "VACUUM ANALYZE;"
}

# Run the query plan specified in query_file
function run_query_plan ()
{
	local i
	for ((i=1; i <= NUM_OF_RUNS; i++))
	do
		psql <<EOF
		SELECT dropdbbuffers('assign3');
		SELECT pg_stat_reset();
EOF
		psql -e ${VARIABLE_ASSIGNMENTS} -f ${query_file} 

		psql <<EOF
		SELECT pg_sleep(2);
		SELECT relname, heap_blks_read, heap_blks_hit, idx_blks_read, idx_blks_hit 
			FROM pg_statio_all_tables WHERE relname IN ('r', 's');
EOF
	done
}


# run different plans for the specified query
function run_query ()
{
	echo "run_query ${query}  ${RUN_QUERY_PLANS} ..."
	for plan in ${RUN_QUERY_PLANS}
	do
		query_file="${ASSIGN_DIR}/q${query}-${plan}.sql"
		if [ -e ${query_file} ]; then
			echo "Running ${query_file} ..."
			output_file=${OUT_DIR}/expt-${expt}-${query}-${plan}-${join_factor}-${workmem}-${bval}.txt
			VARIABLE_ASSIGNMENTS="-v work_mem=${workmem} -v v=${bval}"
			run_query_plan >| ${output_file}
			if [ -e ${output_file} ]; then
				avgtime=$(grep Execution ${output_file} | awk -F" " '{ total += $3; count++ } END { print total/count }')
				info="${expt},${query},${plan},${join_factor},${workmem},${bval},${avgtime}" 
				echo ${info} >> ${performance_data_file}
			fi
		else
			echo "ERROR: ${query_file} missing!"
			exit 1
		fi
	done
}


# remove any existing performance output files
function remove_performance_output_files ()
{
	local query
	for query in ${QUERY_LIST}
	do
		performance_data_file=${OUT_DIR}/expt-${expt}-${query}.txt
		if [ -e ${performance_data_file} ]; then
			rm -f ${performance_data_file}
		fi
	done
}


# Experiment 1 - vary selectivity of selection predicate
function expt1 ()
{
	echo "expt1 ..."

	expt=1
	join_factor=10
	workmem=4096

	remove_performance_output_files
	load_data 

	for index_config in "RS" "R" "S"
	do
		create_index 
		RUN_QUERY_PLANS=${QUERY_PLANS[${index_config}]}
		for bval in 10 100 1000 10000 50000 100000
		do
			for query in ${QUERY_LIST}
			do
				echo "Experiment: ${index_config} ${expt} ${query} bval ${bval}"
				performance_data_file=${OUT_DIR}/expt-${expt}-${query}.txt
				run_query 
			done
		done
	done
	echo "expt1 done!"
}


# initialize stuff
function init ()
{
	echo "init ..."

	export PGUSER=$(whoami)

	VERSION=16.1
	ASSIGN_DIR=$HOME/cs3223-assign3
	if [ ${SLURM} -eq 1 ]; then
		TEMP_DIR=/tmp/${PGUSER}
		OUT_DIR=${TEMP_DIR}/output
		PDF_DIR=${TEMP_DIR}/pdf
		LOG_FILE=${TEMP_DIR}/log.txt
	else 
		TEMP_DIR=$HOME
		OUT_DIR=${ASSIGN_DIR}/output
		PDF_DIR=${ASSIGN_DIR}/pdf
		LOG_FILE=${ASSIGN_DIR}/log.txt
	fi
	SRC_DIR=${TEMP_DIR}/postgresql-${VERSION}
	INSTALL_DIR=${TEMP_DIR}/pgsql-cs3223
	DATA_DIR=${TEMP_DIR}/pgdata-cs3223
	PG_FILE=postgresql-${VERSION}.tar.gz
	DBNAME=assign3

	NUM_OF_RUNS=3
	NUM_R_TUPLES=100000 
	QUERY_LIST="a b c"

	QUERY_PLANS["RS"]="smj hj"
	QUERY_PLANS["R"]="inlj-r smj-r" 
	QUERY_PLANS["S"]="inlj-s smj-s" 

	export PATH=${INSTALL_DIR}/bin:$PATH
	export PGDATA=${DATA_DIR}

	if [ ${SLURM} -eq 1 ] && [ ! -d /tmp ]; then
		echo "ERROR: server $(hostname) has no local /tmp directory!"
		exit 1
	fi

	mkdir -p ${TEMP_DIR}
	if [ ${SLURM} -eq 1 ]; then
		chmod -R go-rwx ${TEMP_DIR}
	fi
	if [ -d ${DATA_DIR} ]; then
		rm -rf ${DATA_DIR}
	fi
	mkdir -p ${INSTALL_DIR}
	mkdir -p ${OUT_DIR}
	mkdir -p ${PDF_DIR}

	chmod u+x ${ASSIGN_DIR}/*.sh
}

# install postgres
function install_postgres ()
{
	echo "install_postgres ..."
	cd ${TEMP_DIR}
	if [ ! -e ${PG_FILE} ]; then
		# Download PostgreSQL source files
		wget https://ftp.postgresql.org/pub/source/v${VERSION}/${PG_FILE}
	fi
	if [ ! -d ${SRC_DIR} ] || [ ! -d ${INSTALL_DIR}/bin ]; then
		# Install PostgreSQL
		tar xvfz ${PG_FILE}
		cd ${SRC_DIR}
		export CFLAGS="-O2"
		./configure --prefix=${INSTALL_DIR}
		#./configure --prefix=${INSTALL_DIR} --enable-debug  --enable-cassert
		#export CFLAGS="-g"
		NUMBER_PARALLEL_TASKS=4
		make clean
		make world
		make install -j ${NUMBER_PARALLEL_TASKS}
	fi
}



# main function
function main ()
{
	echo "main ..."
	if [ ${SLURM} -eq 1 ]; then
		echo "Slurm job running on  $(hostname)  ..."
	fi

	init
	install_postgres

	# create database cluster 
	${INSTALL_DIR}/bin/initdb -D ${DATA_DIR}

	# modify postgresql.conf
	echo "Modifying ${DATA_DIR}/postgresql.conf ..."
	if [ -e ${DATA_DIR}/postgresql.conf ]; then
		# disable parallel processing
		echo "max_parallel_workers = 0" >> ${DATA_DIR}/postgresql.conf
		echo "max_parallel_workers_per_gather = 0" >> ${DATA_DIR}/postgresql.conf
		echo "checkpoint_timeout = 120min" >> ${DATA_DIR}/postgresql.conf
		echo "max_wal_size = 5GB" >> ${DATA_DIR}/postgresql.conf
	else
		echo "ERROR: ${DATA_DIR}/postgresql.conf missing!"
		exit 1
	fi

	# install dropdbbuffers extension
	echo "Installing dropdbbuffers extension ..."
	if [ ! -d ${ASSIGN_DIR}/dropdbbuffers ]; then
		echo "ERROR: ${ASSIGN_DIR}/dropdbbuffers missing!"
		exit 1
	fi
	if [ -d ${SRC_DIR}/contrib/dropdbbuffers ]; then
		\rm -rf ${SRC_DIR}/contrib/dropdbbuffers 
	fi
	cp -r ${ASSIGN_DIR}/dropdbbuffers ${SRC_DIR}/contrib
	cd ${SRC_DIR}/contrib/dropdbbuffers 
	make && make install 


	# start postgres server
	rm -f ${LOG_FILE}
	${INSTALL_DIR}/bin/pg_ctl start -D ${DATA_DIR} -l ${LOG_FILE} -o "-p ${PGPORT}"
	sleep 10


	# check that server is running
	if ! pg_ctl status > /dev/null; then
		echo "ERROR: postgres server is not running!"
		exit 1;
	fi

	# create database
	${INSTALL_DIR}/bin/createdb ${DBNAME}
	export PGDATABASE=${DBNAME}

	# check that number of shared buffer pages is  configured to the default value of 128MB
	if ! psql -c "SHOW shared_buffers;" | grep "128MB"; then
		echo "ERROR: restart server using default number of shared buffers!"
		exit 1;
	fi

	# create dropdbbuffers extension
	psql -c "CREATE EXTENSION IF NOT EXISTS dropdbbuffers;"

	mkdir -p ${ASSIGN_DIR}/output
	mkdir -p ${ASSIGN_DIR}/pdf
	rm -f ${ASSIGN_DIR}/output/*.txt
	rm -f ${ASSIGN_DIR}/pdf/*.pdf

	expt1
	if [ ${SLURM} -eq 1 ]; then
		cp -f ${OUT_DIR}/expt-1-*.txt ${ASSIGN_DIR}/output
		cp -f ${LOG_FILE} ${ASSIGN_DIR}
	fi
	sleep 5
	pg_ctl stop
}


function cleanUp () 
{
	sleep 10
	echo "Cleaning up ..."
	if [ ${SLURM} -eq 1 ]; then
		rm -rf "/tmp/${PGUSER}" 
	fi
}

# clean up on exit
trap cleanUp EXIT

declare -A QUERY_PLANS
main

