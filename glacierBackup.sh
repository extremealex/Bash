#!/bin/bash
# Requirements: openssl curl
#REF => https://gist.github.com/daper/bde5ef75f9430ce800e37f62583a478d

host=$(hostname)
if [[ $host =~ "wp" ]]; then
    CONFIG_FILE_PATH="/var/www/webroot/ctrl/aws.conf"
else
	CONFIG_FILE_PATH="/mapegy/ctrl/aws.conf"
fi

source "${CONFIG_FILE_PATH}"
function getDate {
	date +"%a, %d %b %Y %T %z"
}

# args: <string>
function awsSign {
	echo -en "$1" \
	| openssl sha1 -hmac $S3SECRET -binary \
	| base64
}

# args: <bucketFilePath>
function startMultipart {
	file=$(echo $1 | sed 's/^\///')
	[[ $is_stream ]] && contentType="application/octet-stream" || contentType="application/gzip"
	storageType="x-amz-storage-class:STANDARD"
	dateValue=$(getDate)
	stringToSign="POST\n\n$contentType\n$dateValue\n$storageType\n/$BUCKET_NAME/$1?uploads"
	signature=$(awsSign "$stringToSign")
    checksum="x-amz-checksum-algorithm: SHA1"
	
	resp=$(curl -i --silent -X POST \
		-w "\n%{response_code}" \
		-H "Host: $BUCKET_NAME.s3.amazonaws.com" \
		-H "Date: $dateValue" \
		-H "Content-Type: ${contentType}" \
		-H "$storageType" \
		-H "Authorization: AWS $S3KEY:$signature" \
		"https://$BUCKET_NAME.s3-$REGION.amazonaws.com/$file?uploads" 2>&1)

	# exit on error
	if [ $(echo "$resp" | tail -n1) -ne 200 ]; then
		echo "$resp"
		backupStatus=0
		return 1
	fi
	
	echo "$resp" | tr "\n" " " | sed -n "s/.*<UploadId>\(.*\)<\/UploadId>.*/\1/p"
}

# args: <multiPartId> <bucketFilePath>
function completeMultiPart {
	echo "[i] Finalizing upload..."
	multiPartId=$1
	file=$(echo $2 | sed 's/^\///')
	tmpFilePath='/tmp/aws-upload-meta-'"$multiPartId"'.xml'
	payload=$(<"$tmpFilePath")
	
	resource="/$BUCKET_NAME/$file"
	dateValue=$(getDate)
	echo "here!"
	stringToSign="POST\n\napplication/xml\n$dateValue\n$resource?uploadId=$multiPartId"
	signature=$(awsSign "$stringToSign")
	
	resp=$(curl --silent --progress-bar -i -X POST -T "$tmpFilePath" \
		-w "\n%{response_code}" \
		-H "Host: $BUCKET_NAME.s3.amazonaws.com" \
		-H "Date: $dateValue" \
		-H "Content-Length: ${#payload}" \
		-H "Content-Type: application/xml" \
		-H "Authorization: AWS $S3KEY:$signature" \
		"https://$BUCKET_NAME.s3-$REGION.amazonaws.com/$file?uploadId=$multiPartId")
		
	rm -f "$tmpFilePath"
	
	# exit on error
	if [ $(echo "$resp" | tail -n1) -ne 200 ]; then
		echo "$resp"
		backupStatus=0
		return 1
	fi
}

# args: <multiPartId> <bucketFilePath> <partNumber>
function getHash {
	multiPartId=$1
	file=$(echo $2 | sed 's/^\///')
	part_n=$3
   # mkfifo myfifo
	#cat | openssl dgst -md5 -binary
   # tempfile=$(mktemp -t tmp$part_n.XXXXXXXXXX) && cat | tee >({ openssl dgst -md5 -binary | base64 > $tempfile; wait < <(jobs -p); val=$(cat $tempfile); wait < <(jobs -p); echo "hoohaa: $val"; sleep 5; }) >/dev/null
   
  # tempfile=$(mktemp -t tmp$part_n.XXXXXXXXXX) && cat | tee >({ openssl dgst -md5 -binary | base64 > $tempfile; HASH=$(cat $tempfile); echo "test1: $HASH"; }) | (putPart "$multiPartId" "$file" "$part_n") # | tee >({ echo "test: $val"; cat $tempfile; })> /dev/null
    
    #tempfile=$(mktemp) && cat - | tee >(openssl dgst -md5 -binary | base64 > $tempfile) | { wait < <(jobs -p) && hash=$(cat "$tempfile") && rm "$tempfile" && echo "hash: $hash"; }
    touch /tmp/calchash
    tempfile=$(mktemp) && cat - | tee >( { calcHash $tempfile; } ) | tee >({ while [ -e /tmp/calchash ]; do echo "it does"; sleep 0.1; done; hash=$(head -1 $tempfile); putPart "$multiPartId" "$file" "$part_n" "$hash"; } )
    # | {  } #| { sleep 5 && hash=$(cat "$tempfile") && echo "hash: $hash" && echo "pid: $PID"; }
    #sh -c 'PID=$(echo $$) ;exec 
    #| tee >(putPart "$multiPartId" "$file" "$part_n" "$val") >/dev/null
    # > tee >(putPart "$multiPartId" "$file" "$part_n" "$tempfile") >/dev/null

    ####chunk=$(cat </dev/stdin | base64) #| { var=`cat`; printf "%s" "${var}"; }
    #base64 | md5sum | | awk '{print $1}' is incorrect here
    ####MD5Hash=$(printf "$chunk\n" | base64 -d | openssl dgst -md5 -binary)
    ##echo $PID; 
    #echo "chunk: $part_n"
    ####contentMD5=$(echo -n "$MD5Hash" | base64)
   # echo "hashBase64: $contentMD5"
    
   ####printf "$chunk\n" | base64 -d | putPart "$multiPartId" "$file" "$part_n" "$contentMD5"
}
function calcHash {
	
	cat | openssl dgst -md5 -binary | base64 >$1
    rm -f /tmp/calchash
    #pid=$(ps auxf|grep "openssl"|awk '{print $2}'); 
    
}

# args: <multiPartId> <bucketFilePath> <partNumber> <chunkMD5Hash>
function putPart {
	
    #while [ $(wc -c $tempfile | awk '{print $1}') -lt 25 ]; do echo "it does"; sleep 0.1; done
    #while [ -e /tmp/calchash ]; do echo "it does"; sleep 0.1; done
	multiPartId=$1
	file=$(echo $2 | sed 's/^\///')
	part_n=$3
    contentMD5=$4
    #echo "from putPart: $chunkHash"
    
    #echo "here" && cat
    ####contentMD5=$4
    #sleep 1 && contentMD5=$(cat $chunkHash)
    ##cat $chunkHash
    ##echo " "
    #contentMD5="$(echo -e -n $contentMD5Bin | base64)"
    echo "test:$contentMD5"
    #chunkHash=$4
    #contentMD5=$(base64 $chunkHash)
    #echo "content md5-$part_n: $contentMD5"
    #rm $chunkHash
    
     #try chunk upload
	for (( c=1; c<=$RETRY; c++ ))
   	do
    	#echo "content md5-$part_n: $contentMD5" 
		echo "[i] Uploading part $part_n... "
		
		resource="/$BUCKET_NAME/$file?partNumber=$part_n&uploadId=$multiPartId"
		dateValue=$(getDate)
		contentType="application/octet-stream"
        #Order is reserved. \n if any section is skipped.
		stringToSign="PUT\n$contentMD5\n$contentType\n$dateValue\n$resource"
		signature=$(awsSign "$stringToSign")
        
    	# upload chunk
		resp=$(curl --silent -i -X PUT --data-binary @/dev/stdin \
			-w "\n%{response_code}" \
			-H "Host: $BUCKET_NAME.s3.amazonaws.com" \
			-H "Date: $dateValue" \
			-H "Content-Type: ${contentType}" \
            -H "Content-MD5: ${contentMD5}" \
			-H "Authorization: AWS $S3KEY:$signature" \
			"https://$BUCKET_NAME.s3-$REGION.amazonaws.com/$file?partNumber=$part_n&uploadId=$multiPartId")
	    
        # retry on error
		if [ $(echo "$resp" | tail -n1) -eq 200 ]; then
        	#echo "$resp"
        	break;
        else
        	if (( $c<$RETRY )); then
                echo "$resp"
                echo "Retry $c"
            else
            	echo "$dateValue: Ran out of retries and failed to complete the upload!"
            fi
		fi
    done
    
    # exit on error
	if [ $(echo "$resp" | tail -n1) -ne 200 ]; then
		echo "$resp"
		backupStatus=0
		return 1
	fi
    
	etag=$(echo "$resp" | sed -n 's/.*ETag: "\(.*\)".*/\1/p')
	
	tmpFilePath='/tmp/aws-upload-meta-'"$multiPartId"'.xml'
	echo "<Part><PartNumber>$part_n</PartNumber><ETag>$etag</ETag></Part>" >> "$tmpFilePath"
}

# args: <fileName>
function deleteFile {
	# metadata
	bucketName=$BUCKETNAME
	filePath=$1
	contentType="application/octet-stream"
	dateValue=$(getDate)
	fullPath="/${bucketName}/${filePath}"
	stringToSign="DELETE\n\n${contentType}\n${dateValue}\n${fullPath}"
	signature=$(awsSign "$stringToSign")

	curl -X "DELETE" https://${bucketName}.s3.${REGION}.amazonaws.com/${filePath} \
		-H "Host: ${bucketName}.s3.${REGION}.amazonaws.com" \
        -H "Date: ${dateValue}" \
        -H "Content-Type: ${contentType}" \
        -H "Authorization: AWS ${S3KEY}:${signature}" 
}

export -f completeMultiPart
export -f startMultipart
export -f deleteFile
export -f putPart
export -f getHash
export -f awsSign
export -f getDate
export is_stream=0
export HASH=""
export -f calcHash

# args: <absSourcePath> <bucketName> <Optional:folderName>
function initiate {
	export backupStatus=1
    
    if [ $is_stream -eq 1 ]; then
    	destination="$FILE_NAME"
    else
    	export BUCKET_NAME=$2
	    # load source path
		absSourcePath=$1
		if [[ "$absSourcePath" != /* ]]; then echo "Path must be absolute." 1>&2; return 1; fi
		
		if [[ -d "$absSourcePath" ]]; then
			# source is directory
			filename='.'
			directory="$absSourcePath"
			uploadName=$(basename "$absSourcePath")
		else
			# source is file
			filename=$(basename "$absSourcePath")
			directory=$(dirname "$absSourcePath")
			uploadName="$filename"
		fi
        
        if [[ $uploadName =~ ".tar.gz" ]]; then
			destination="$uploadName"
        else
        	destination="$uploadName.tar.gz"
		fi
        
        if [ ! -z $3 ]; then
        	destination="$3/$destination"
		fi
		
    fi
    	
	# init upload
	echo "[i] Initializing AWS S3 Glacier upload '$destination', $(getDate)"
	multiPartId=$(startMultipart $destination bucketName)
	
	# init temp file for meta data
	tmpFilePath='/tmp/aws-upload-meta-'"$multiPartId"'.xml'
	echo "[i] tmpFilePath = $tmpFilePath"
	echo "<CompleteMultipartUpload>" > "$tmpFilePath"
	
	# archive, split and upload
	echo "[i] Creating archive..."
    
    if [ $is_stream -eq 0 ]; then
		tar -cf - --no-auto-compress -C $directory $filename | split -b "$CHUNK_SIZE"M -a 8 -d \
			--filter='source "'"${CONFIG_FILE_PATH}"'"; getHash "'"$multiPartId"'" "'"$destination"'" $((10#$FILE+1)) < /dev/stdin' - ""
    else
    	cat < /dev/stdin |  gpg --no-default-keyring --keyring $RECIPIENT -er $RECIPIENT_ID --trust-model always  -z 9 --batch --yes --encrypt | split -b "$CHUNK_SIZE"M -a 8 -d \
			--filter='source "'"${CONFIG_FILE_PATH}"'"; putPart "'"$multiPartId"'" "'"$destination"'" $((10#$FILE+1)) < /dev/stdin' - ""
    fi		
	# exit on error
	if [ $? != 0 ]; then
		rm -f "$tmpFilePath"
		echo "An error occured during the upload." 1>&2;
		backupStatus=0
		return 1;
	fi
	
	# finalize upload
	echo "</CompleteMultipartUpload>" >> "$tmpFilePath"
	completeMultiPart $multiPartId $destination
	
	# exit on error
	if [ $? != 0 ]; then
		rm -f "$tmpFilePath"
		backupStatus=0
		echo "An error occured." 1>&2;
		return 1;
	fi
	
	echo "[i] Upload completed."
}

# Detect piped data for uploading streams
if [ $1 == "-" ]; then
	export is_stream=1
    export BUCKET_NAME=$2
    export FILE_NAME=$3
    
	initiate
else
    initiate $1 $2 $3
fi
