# Include tools for TCG Opal support

has_binary sedutil-cli || return 0

PROGS+=( sedutil-cli )
KERNEL_CMDLINE+=" libata.allow_tpm=1"
