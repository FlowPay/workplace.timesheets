## Verify that tthe openapi file is valid using prism, if it is, mv it to the correct location
## Source file and destination path are passed as arguments

kill -9 $(lsof -t -i:8888) 

# Check that the file is valid
prism mock $1 -m -p 8888 &
sleep 2
#check if server is started on port 8888, if yes, move file then kill server. If not, exit
if [ -z "$(lsof -t -i:8888)" ]; then
    echo "File is not valid"
    exit 1
else
    cp $1 $2
    echo "File moved to $2"
    kill -9 $(lsof -t -i:8888)
fi


