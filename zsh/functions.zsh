function helpers() {
  if ! [ -f .project-helpers ]
  then
    echo "This project does not have any helpers."
  else
    source .project-helpers
    echo "Loaded project helpers"
  fi
}