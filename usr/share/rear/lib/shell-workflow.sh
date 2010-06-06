WORKFLOW_shell () {
	for arg in "${ARGS[@]}" ; do
		key=OPT_"${arg%%=*}"
		val="${arg#*=}"
		declare $key="$val"
		Log "Setting $key=$val"
	done

	# very clumsy way to export everything
	#export MODULES PROGS
	#export ${!A*} ${!B*} ${!C*} ${!D*} ${!E*} ${!F*} ${!G*} ${!H*} ${!I*} ${!J*} ${!K*} ${!L*} ${!M*} ${!N*} ${!O*} ${!P*} ${!Q*} ${!R*} ${!S*} ${!T*} ${!U*} ${!V*} ${!W*} ${!X*} ${!Y*} ${!Z*}
	mkfifo $TMP_DIR/rear-shell.fifo
	export SHELL_VARS_FIFO=$TMP_DIR/rear-shell.fifo
	declare -p >$SHELL_VARS_FIFO </dev/null &
	bash --rcfile $SHARE_DIR/lib/bashrc.rear -i 2>&1
	
}
