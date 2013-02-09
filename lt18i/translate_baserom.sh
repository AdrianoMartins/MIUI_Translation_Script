PRJ_DIR=`pwd`
PORT_ROOT=/home/adrianomartins/Android/miui_jb
SOURCE_ZIP=$PRJ_DIR/baserom.zip
METADATA_DIRMETADATA_DIR=$PRJ_DIR/metadata
OUT_DIR=$PRJ_DIR/out
ZIP_DIR=$OUT_DIR/ZIP
TARGET_FILES_DIR=$OUT_DIR/target_files
TARGET_FILES_ZIP=$OUT_DIR/target_files.zip
TARGET_FILES_TEMPLATE_DIR=$PORT_ROOT/tools/target_files_template
TOOL_DIR=$PORT_ROOT/tools
OTA_FROM_TARGET_FILES=$TOOL_DIR/releasetools/ota_from_target_files
SIGN_TARGET_FILES_APKS=$TOOL_DIR/releasetools/sign_target_files_apks
OUT_ZIP_FILE=miui_jb.zip
NO_SIGN=false
RES_LANGUAGES_FOLDER=$PRJ_DIR/languages_res
TMP_FOLDER_LANGUAGES_BUILD=$PRJ_DIR/tmp_languages_res
APKTOOL_EXTERNAL=$PORT_ROOT/tools_external/apktool
APKTOOL=$PORT_ROOT/tools_external/apktool
#APKTOOL=$PORT_ROOT/tools/apktool

# copy the whole target_files_template dir
function copy_target_files_template {
    echo "Copy target file template into current working directory"
    rm -rf $TARGET_FILES_DIR
    mkdir -p $TARGET_FILES_DIR
    cp -r $TARGET_FILES_TEMPLATE_DIR/* $TARGET_FILES_DIR
}

function unzip_source {
    echo "Unzip Base ROM"
    rm -rf $ZIP_DIR
    mkdir -p $ZIP_DIR
    unzip -o -q $SOURCE_ZIP -d $ZIP_DIR

echo "Installing frameworks..."
$APKTOOL if $ZIP_DIR/system/framework/framework-res.apk
$APKTOOL if $ZIP_DIR/system/framework/framework-miui-res.apk

}

function apply_translation_res {
mkdir -p $TMP_FOLDER_LANGUAGES_BUILD
	for file in $RES_LANGUAGES_FOLDER/*
	do
		if [[ $(basename $file) != lockscreen ]]; then
		  echo "Processing translation for $(basename $file).apk file..."
			if [ -f "$ZIP_DIR/system/app/$(basename $file).apk" ] 
				then
				$APKTOOL d -f $ZIP_DIR/system/app/$(basename $file).apk $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file)
				cp -rf $file/* $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file)
				$APKTOOL b $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file) $ZIP_DIR/system/app/$(basename $file).apk
				rm -rf $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file)
			elif [ -f "$ZIP_DIR/system/framework/$(basename $file).apk" ] 
				then
                if [[ $(basename $file) == framework-miui-res ]]; then
                    $APKTOOL_EXTERNAL d -f $ZIP_DIR/system/framework/$(basename $file).apk $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file)
                    cp -rf $file/* $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file)
                    $APKTOOL_EXTERNAL b $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file) $ZIP_DIR/system/framework/$(basename $file).apk
				else
                    $APKTOOL d -f $ZIP_DIR/system/framework/$(basename $file).apk $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file)
                    cp -rf $file/* $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file)
                    $APKTOOL b $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file) $ZIP_DIR/system/framework/$(basename $file).apk
				fi
				rm -rf $TMP_FOLDER_LANGUAGES_BUILD/$(basename $file)
			else
				echo "Translation for $(basename $file).apk file end unsuccessfully..."
			fi
		else
		  echo "Processing translation for $(basename $file) file..."	
			unzip -o -q $ZIP_DIR/system/media/theme/default/lockscreen -d $TMP_FOLDER_LANGUAGES_BUILD/lockscreen
			cp -f $RES_LANGUAGES_FOLDER/lockscreen/manifest* $TMP_FOLDER_LANGUAGES_BUILD/lockscreen/advance/
			cd $TMP_FOLDER_LANGUAGES_BUILD/lockscreen/
			zip -q -r -y $ZIP_DIR/system/media/theme/default/lockscreen .
			cd -
			mv $ZIP_DIR/system/media/theme/default/lockscreen.zip $ZIP_DIR/system/media/theme/default/lockscreen
			rm -rf $TMP_FOLDER_LANGUAGES_BUILD/lockscreen
		fi
	done
rm -rf $TMP_FOLDER_LANGUAGES_BUILD
}

function copy_bootimage {
    echo "Copy bootimage"
    for file in boot.img zImage */boot.img */zImage
    do
        if [ -f $ZIP_DIR/$file ]
        then
            cp $ZIP_DIR/$file $TARGET_FILES_DIR/BOOTABLE_IMAGES/boot.img
            return
        fi
    done
}

function copy_system_dir {
    echo "Copy system dir"
    cp -rf $ZIP_DIR/system/* $TARGET_FILES_DIR/SYSTEM
}

function copy_data_dir {
    #The thirdpart apps have copyed in copy_target_files_template function,
    #here, just to decide whether delete them.
    if [ $INCLUDE_THIRDPART_APP = "true" ];then
       echo "Copy thirdpart apps"
    else
       rm -rf $TARGET_FILES_DIR/DATA/*
    fi
    echo "Copy miui preinstall apps"
    mkdir -p $TARGET_FILES_DIR/DATA/
    cp -rf $ZIP_DIR/data/media/preinstall_apps $TARGET_FILES_DIR/DATA/
    if [ -f customize_data.sh ];then
        ./customize_data.sh $PRJ_DIR
    fi
}


# compress the target_files dir into a zip file
function zip_target_files {
    echo "Compress the target_files dir into zip file"
    #echo $TARGET_FILES_DIR
    cd $TARGET_FILES_DIR
    #echo "zip -q -r -y $TARGET_FILES_ZIP *"
    rm -f $TARGET_FILES_ZIP
    zip -q -r -y $TARGET_FILES_ZIP *
    cd -
}

function sign_target_files {
    echo "Sign target files"
    $SIGN_TARGET_FILES_APKS -d $PORT_ROOT/build/security $TARGET_FILES_ZIP temp.zip
    mv temp.zip $TARGET_FILES_ZIP
}

# build a new full ota package
function build_ota_package {
    echo "Build full ota package: $OUT_DIR/$OUT_ZIP_FILE"
    $OTA_FROM_TARGET_FILES -n -k $PORT_ROOT/build/security/testkey $TARGET_FILES_ZIP $OUT_DIR/$OUT_ZIP_FILE
}


if [ $# -eq 3 ];then
    NO_SIGN=true
    OUT_ZIP_FILE=$3
    INCLUDE_THIRDPART_APP=$1
elif [ $# -eq 2 ];then
    OUT_ZIP_FILE=$2
    INCLUDE_THIRDPART_APP=$1
elif [ $# -eq 1 ];then
    INCLUDE_THIRDPART_APP=$1
fi

cd ..
. build/envsetup.sh
cd $PRJ_DIR
unzip_source
copy_target_files_template
apply_translation_res
copy_bootimage
copy_system_dir
#copy_data_dir
if [ -f "customize_target_files.sh" ]; then
    ./customize_target_files.sh
    if [ $? -ne 0 ];then
       exit 1
    fi
fi
zip_target_files
#sign_target_files
build_ota_package
cd $PRJ_DIR/other
zip -uq $OUT_DIR/$OUT_ZIP_FILE META-INF/com/google/android/updater-script
cd -
echo "Done."
