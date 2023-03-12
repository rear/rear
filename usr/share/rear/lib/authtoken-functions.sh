#!/bin/bash

function authtkn_load() {
	# $1 container path
	# $2 container offset
	# $3 encryption key
	# $4 [bound_to_blockdev path]

	local intermediate_key=""
	local cipher
	local plain
	local ret

	cipher=$(token_read "$1" "$2"); ret=$?
	if [ $ret -ne 0 ]; then
		echo "authtkn_load(): token_read() failed: $ret" >&2
		return $ret
	fi

	if [ -n "$4" ]; then
		intermediate_key=$(blkdev_hash "$4" 2); ret=$?
		if [ $ret -ne 0 ]; then
			echo "authtkn_load(): failed to derive intermediate key from $4: $ret" >&2
			return $ret
		fi
	fi

	plain=$(decrypt_base64 "$cipher" "$3" "$intermediate_key"); ret=$?
	if [ $ret -ne 0 ]; then
		echo "authtkn_load(): decrypt_base64() failed: $ret" >&2
		return $ret
	fi

	echo $plain
	return 0
}

function authtkn_store() {
	# $1 container path
	# $2 container offset
	# $3 token plaintext
	# $4 encryption key
	# $5 [bind_to_blockdev path]

	local intermediate_key=""
	local cipher
	local tknlen
	local ret

	if [ -n "$5" ]; then
		intermediate_key=$(blkdev_hash "$5" 2); ret=$?
		if [ $ret -ne 0 ]; then
			echo "authtkn_store(): failed to derive intermediate key from $5: $ret" >&2
			return $ret
		fi
	fi

	cipher=$(encrypt_base64 "$3" "$4" "$intermediate_key"); ret=$?
	if [ $ret -ne 0 ]; then
		echo "authtkn_store(): encrypt_base64() failed: $ret" >&2
		return $ret
	fi

	tknlen=$(token_write "$cipher" "$1" "$2"); ret=$?
	if [ $ret -ne 0 ]; then
		echo "authtkn_store(): token_write() failed: $ret" >&2
		return $ret
	fi

	echo $tknlen
	return 0
}

function authtkn_wipe() {
	# $1 container path
	# $2 container offset
	# $3 [token length]

	# ensure byte-length counting
	LANG=C LC_ALL=C

	local ret
	local length
	local token

	if [ -z "$3" ]; then
		# taking existing token length
		token=$(token_read "$1" "$2")
		[[ $? -eq 0 ]] && length=${#token}
	else
		length=$3
	fi

	# will fail if length still undef
	token=$(garbage_base64 $length); ret=$?
	if [ $ret -ne 0 ]; then
		echo "authtkn_wipe(): garbage_base64() failed: $ret" >&2
		return $ret
	fi

	length=$(token_write "$token" "$1" "$2"); ret=$?
	if [ $ret -ne 0 ]; then
		echo "authtkn_wipe(): token_write() failed: $ret" >&2
		return $ret
	fi

	echo $length
	return 0
}


function token_read() {
	# $1 path
	# $2 [offset:0]
	# $3 [retries:2]

	# ensure byte-length counting
	LANG=C LC_ALL=C

	if [ -z "$1" ]; then
		echo "token_read(): none or empty token container path given" >&2
		return 1
	fi

	local rawchunk
    local length
    local payload
    local ret

	rawchunk="$(blkdev_read $1 4096 ${2:-0} ${3:-2})"; ret=$?
	if [ $ret -ne 0 ]; then
		echo "token_read(): blkdev_read() failed: $ret" >&2
		return $ret
	fi

	length=$(base64 -d <<< "${rawchunk:0:8}" 2>/dev/null | tr -d '\0' 2>/dev/null)
	if [ ${#length} -ne 5 ] || [[ $length =~ [^0-9] ]]; then
		echo "token_read(): read failed: invalid length specifier" >&2
		return 2
	fi
	length=$((10#$length))
	if (( length <= 0 )); then
		echo "token_read(): read failed: invalid length specifier" >&2
		return 2
	fi

	payload=${rawchunk:8:$length}
	if (( ${#payload} != $length )); then
		echo "token_read(): read failed: length mismatch: ${#payload} instead of expected $length" >&2
		return 2
	fi

	echo $payload
	return 0
}

function token_write() {
	# $1 payload
	# $2 path
	# $3 [offset:0]
	# $4 [retries:2]

	# ensure byte-length counting
	LANG=C LC_ALL=C

	local lenwr=${#1}
	# 4096 - 8 (lenb64) = 4088
	if [ -z "$1" ] || [ $lenwr -gt 4088 ]; then
		echo "token_write(): given payload is empty or too big: $lenwr" >&2
		return 1
	fi

	local lenb64
	local ret

	#supporting up to 5-figure length
	lenb64=$(base64 <<< $(printf '%05d' $lenwr) 2>/dev/null)
	if [ ${#lenb64} -ne 8 ]; then
		echo "token_write(): failed to encode token length specifier" >&2
		return 2
	fi

	lenwr=$(blkdev_write "${lenb64}${1}" "$2" ${3:-0} ${4:-2}); ret=$?
	if [ $ret -ne 0 ]; then
		echo "token_write(): blkdev_write() failed: $ret" >&2
		return $ret
	fi

	echo $lenwr
	return 0
}


function blkdev_hash() {
	# $1 block dev path
	# $2 [retries:1]

	# RETRY CASE: see notes in blkdev_read()

	if [ -z "$1" ]; then
		echo "blkdev_hash(): none or empty path given" >&2
		return 1
	fi

	local retries=${2:-1}
	local hash

	while [ -z "$hash" ]; do
		if [ ! -b "$1" ]; then
			echo "blkdev_hash(): blockdev path [$1] is invalid or device not yet ready" >&2
		elif [ ! -r "$1" ]; then
			echo "blkdev_hash(): missing read perm on given blockdev [$1]" >&2
		else
			hash="$(b2sum --binary $1 2>&1)"
			if [ $? -ne 0 ]; then
				echo "blkdev_hash(): hashing failed: $hash" >&2 # hash is stderr here
				hash=""
			else
				hash="${hash//\\/}"
				hash="${hash:0:128}"
				break
			fi
		fi

		(( retries > 0 )) && blkdev_wait "$1" 1 || break
		(( retries -= 1 ))
	done

	[[ -n "$hash" ]] && echo "$hash" || return 2
}

function blkdev_read() {
	# $1 block dev path
	# $2 length
	# $3 [offset:0]
	# $4 [retries:1]

	# RETRY CASE: valid and blkdev_wait() passed dev might still fail being accessed right after boot
	# Trivial debugging revealed that in the moment of fail the relevant /dev/ node doesn't exist
	# However it was definitely there just before (passed blkdev_wait and other checks) and relevant /dev/disk/by-*/ are also there
	# The node then just reappears a moment later, and there is nothing faulty in dmesg
	# All sorts of failures possible: test -b, dd zero-len, dd in-the-middle
	# Reproducible at least in QEMU with SATA vdisks

	# ensure byte-length counting
	LANG=C LC_ALL=C

	if [ -z "$1" ] || [ -z "$2" ] || (( $2 <= 0 )); then
		echo "blkdev_read(): bad call: invalid arguments" >&2
		return 1
	fi

	local retries=${4:-1}
	local data

	while [ -z "$data" ]; do
		if [ ! -b "$1" ]; then
			echo "blkdev_read(): blockdev path [$1] is invalid or device not yet ready" >&2
		elif [ ! -r "$1" ]; then
			echo "blkdev_read(): missing read perm on given blockdev [$1]" >&2
		else
			# Replacing NULLs as they are var-terminators in bash, but preserving data byte-length
			data=$(dd if="$1" bs=$2 count=1 iflag=skip_bytes skip=${3:-0} status=none 2>/dev/null | sed 's/\x00/\x1a/g' 2>/dev/null)
			if [ ${#data} != $2 ]; then #watch out for LANG & LC_ALL
				echo "blkdev_read(): read failed: only ${#data} out of $2 bytes read" >&2
				data=""
			else
				break
			fi
		fi

		(( retries > 0 )) && blkdev_wait "$1" 1 || break
		(( retries -= 1 ))
	done

	[[ -n "$data" ]] && echo "$data" || return 2
}

function blkdev_write() {
	# $1 data
	# $2 block dev path
	# $3 [offset:0]
	# $4 [retries:1]

	# RETRY CASE: see notes in blkdev_read()

	# ensure byte-length counting
	LANG=C LC_ALL=C

	if [ -z "$1" ] || [ -z "$2" ]; then
		echo "blkdev_write(): bad call: invalid arguments" >&2
		return 1
	fi

	local retries=${4:-1}
	local error
	local lenwr

	while [ -z "$lenwr" ]; do
		if [ ! -b "$2" ]; then
			echo "blkdev_write(): blockdev path [$2] is invalid or device not yet ready" >&2
		elif [ ! -w "$2" ]; then
			echo "blkdev_write(): missing write perm on given blockdev [$2]" >&2
		else
			lenwr=${#1}
			error=$(dd of="$2" bs=$lenwr count=1 oflag=seek_bytes seek=${3:-0} conv=notrunc,fsync status=none <<< "$1" 2>&1)
			if [ $? -ne 0 ]; then
				echo "blkdev_write(): write failed: $error" >&2
				lenwr=""
			else
				break
			fi
		fi

		(( retries > 0 )) && blkdev_wait "$2" 1 || break
		(( retries -= 1 ))
	done

	[[ -n "$lenwr" ]] && echo "$lenwr" || return 2
}

function blkdev_model() {
	# $1 block dev path
	# $2 [retries:1]

	# RETRY CASE: see notes in blkdev_read()

	if [ -z "$1" ]; then
		echo "blkdev_model(): none or empty path given" >&2
		return 1
	fi

	local retries=${2:-1}
    local model
    local pdev

    while [ -z "$model" ]; do
		if [ ! -b "$1" ]; then
			echo "blkdev_model(): blockdev path [$1] is invalid or device not yet ready" >&2
		else
			model="$(lsblk -no MODEL $1 2>&1)"
			if [ $? -ne 0 ]; then
				echo "blkdev_model(): lsblk[$1] failed: $model" >&2
				model=""
			elif [ -z "$model" ]; then
				# Succeeded, but no model info, trying parent dev
				pdev="$(lsblk -pno PKNAME $1 2>&1)"
				if [ $? -ne 0 ]; then
					echo "blkdev_model(): lsblk[$1] failed: $pdev" >&2
				else
					pdev="${pdev//[[:space:]]/}"
					[[ -n "$pdev" ]] && model=$(lsblk -no MODEL "$pdev" 2>&1) || model="$1"
					if [ $? -ne 0 ]; then
						echo "blkdev_model(): lsblk[$pdev] failed: $model" >&2
						model=""
					else
						# parent also has no model info
						[[ -z "$model" ]] && model="$pdev"
						break
					fi
				fi
			else
				break
			fi
		fi

		(( retries > 0 )) && blkdev_wait "$1" 1 || break
		(( retries -= 1 ))
	done

    [[ -n "$model" ]] && echo "$model" || echo "$1"
}

function blkdev_wait() {
	# $1 block dev path
	# $2 [timo_init_sec:3]	wait dev initialized, 0 disables this wait
	# $3 [timo_added_sec:0]	wait dev just added (before waiting for init), 0 disables this wait

	# Separate timos allow waiting for dev being added for some short time
	# and then continue waiting longer for init only if dev actually present
	# might be useful with slow USB media

	if [ -z "$1" ]; then
		echo "blkdev_wait(): none or empty path given" >&2
		return 1
	fi

	local timo_i=${2:-3}
	local timo_a=${3:-0}
	local error

	if (( timo_a <= 0 && timo_i <= 0 )); then
		echo "blkdev_wait(): bad call: invalid arguments" >&2
		return 1
	fi

	if (( timo_a > 0 )); then
		echo "blkdev_wait(): waiting up to $timo_a sec for blockdev $1 being added ..." >&2
		error=$(udevadm wait --initialized=false --timeout=$timo_a "$1" 2>&1)
		if [ $? -ne 0 ]; then
			echo "blkdev_wait(): timeout add-waiting for $1: $error" >&2
			return 2
		fi
	fi
	if (( timo_i > 0 )); then
		echo "blkdev_wait(): waiting up to $timo_i sec for blockdev $1 being init ..." >&2
		error=$(udevadm wait --initialized=true --timeout=$timo_i "$1" 2>&1)
		if [ $? -ne 0 ]; then
			echo "blkdev_wait(): timeout init-waiting for $1: $error" >&2
			return 2
		fi
	fi

	return 0
}


function encrypt_base64() {
	# $1 plaintext
	# $2 key (string key or "tpm:credname:PCRs" to use TPM2)
	# $3 [intermediate_key] - double encryption

	if [ -z "$1" ] || [ -z "$2" ]; then
		echo "encrypt_base64(): bad call: missing required args" >&2
		return 1
	fi

	local plaintext
	local ciphertext
	local tmp
	local ret

	if [ -n "$3" ]; then
		plaintext=$(encrypt_base64 "$1" "$3"); ret=$?
		if [ $ret -ne 0 ]; then
			echo "encrypt_base64(): intermediate-encrypt failed: $ret" >&2
			return $ret
		fi
	else
		plaintext="$1"
	fi

	if [ "${2:0:4}" == "tpm:" ]; then
		systemd-creds has-tpm2 >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "encrypt_base64(): TPM-assisted encryption requested but host has no TPM2 available" >&2
			return 2
		fi
		tmp="${2:4}"
		ciphertext=$(systemd-creds --with-key=tpm2 --name="${tmp%:*}" --tpm2-pcrs="${tmp##*:}" encrypt - - <<< "$plaintext" 2>&1); ret=$?
	else
		ciphertext=$(openssl aes-256-cbc -a -pbkdf2 -pass pass:"$2" <<< "$plaintext" 2>&1); ret=$?
	fi
	if [ $ret -ne 0 ]; then
		echo "encrypt_base64(): failed to encrypt token: $ret: $ciphertext" >&2 # ciphertext is stderr here
		return 2
	fi

	ciphertext=$(tr -d '\r\n' <<< "$ciphertext" 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "encrypt_base64(): ciphertext postprocessing failed" >&2
		return 2
	fi
	if [ -z "$ciphertext" ]; then
		echo "encrypt_base64(): failed to encrypt token: got empty ciphertext" >&2
		return 2
	fi

	echo $ciphertext
	return 0
}

function decrypt_base64() {
	# $1 ciphertext
	# $2 key (string key or "tpm:credname:PCRs" to use TPM2)
	# $3 [intermediate_key] - double encryption

	if [ -z "$1" ] || [ -z "$2" ]; then
		echo "decrypt_base64(): bad call: missing required args" >&2
		return 1
	fi

	local plaintext
	local tmp
	local ret

	if [ "${2:0:4}" == "tpm:" ]; then
		systemd-creds has-tpm2 >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "decrypt_base64(): TPM-assisted decryption requested but host has no TPM2 available" >&2
			return 2
		fi
		tmp="${2:4}"
		plaintext=$(systemd-creds --with-key=tpm2 --name="${tmp%:*}" decrypt - - <<< "$1" 2>/dev/null); ret=$?
	else
		plaintext=$(openssl aes-256-cbc -d -a -A -pbkdf2 -pass pass:"$2" <<< "$1" 2>/dev/null); ret=$?
	fi
	if [ $ret -ne 0 ]; then
		echo "decrypt_base64(): failed to decrypt token: $ret" >&2
		return 2
	fi
	if [ -z "$plaintext" ]; then
		echo "decrypt_base64(): failed to decrypt token: got empty plaintext" >&2
		return 2
	fi

	if [ -n "$3" ]; then
		plaintext=$(decrypt_base64 "$plaintext" "$3"); ret=$?
		if [ $ret -ne 0 ]; then
			echo "decrypt_base64(): intermediate-decrypt failed: $ret" >&2
			return $ret
		fi
	fi

	echo $plaintext
	return 0
}

function garbage_base64() {
	# $1 length
	# $2 [relaxed length]
	# $3 [source:/dev/urandom]

	# ensure byte-length counting
	LANG=C LC_ALL=C

	if [ -z "$1" ] || (( $1 <= 0 )); then
		echo "garbage_base64(): none or invalid length requested" >&2
		return 1
	fi

	local garbage

	garbage=$(dd if="${3:-/dev/urandom}" bs=$1 count=1 status=none 2>/dev/null | base64 --wrap=0 2>/dev/null)
	if [ -z "$garbage" ]; then
		echo "garbage_base64(): failed to collect any garbage data" >&2
		return 2
	fi
	if [ -z "$2" ] && [ ${#garbage} -lt $1 ]; then
		echo "garbage_base64(): failed to collect enough garbage: only ${#garbage} out of $1 collected" >&2
		return 2
	fi

	echo "${garbage:0:$1}"
	return 0
}
