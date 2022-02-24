function share() {
    file="$1"

    eval "curl --upload-file ${file} https://free.keep.sh"
}
