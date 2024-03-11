function ph() {
  if ! [ -f .project-helpers ]
  then
    return
  else
    source .project-helpers
    echo "Loaded project helpers"
  fi
}