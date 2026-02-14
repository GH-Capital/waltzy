#!/bin/bash

# Configuration
ext_name="lunaranime"
ext_class="Lunaranime"
ext_lang="id"
repo_owner="GH-Capital"
repo_name="waltzy"

# Ensure variables are set
if [ -z "$ext_name" ] || [ -z "$ext_class" ]; then
    echo "Error: ext_name and ext_class must be set."
    exit 1
fi

# Directory structure
base_dir="src/${ext_lang}/${ext_name}"
package_name="eu.kanade.tachiyomi.extension.${ext_lang}.${ext_name}"
package_path="src/${ext_lang}/${ext_name}/src/eu/kanade/tachiyomi/extension/${ext_lang}/${ext_name}"

# Check if directory exists
if [ -d "$base_dir" ]; then
    echo "Extension directory $base_dir already exists. Skipping creation."
else
    echo "Creating extension directory structure..."
    mkdir -p "$base_dir/res/mipmap-hdpi"
    mkdir -p "$base_dir/res/mipmap-mdpi"
    mkdir -p "$base_dir/res/mipmap-xhdpi"
    mkdir -p "$base_dir/res/mipmap-xxhdpi"
    mkdir -p "$base_dir/res/mipmap-xxxhdpi"
    mkdir -p "$package_path"

    # Create build.gradle
    cat <<EOF > "$base_dir/build.gradle"
apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'

ext {
    extName = '$ext_class'
    pkgNameSuffix = '$ext_lang.$ext_name'
    extClass = '.$ext_class'
    extVersionCode = 1
}

apply from: "\$rootDir/common.gradle"
EOF

    # Create Kotlin file
    cat <<EOF > "$package_path/$ext_class.kt"
package $package_name

import eu.kanade.tachiyomi.multisrc.madara.Madara
import java.text.SimpleDateFormat
import java.util.Locale

class $ext_class : Madara("$ext_class", "https://$ext_name.com", "$ext_lang", SimpleDateFormat("MMM d, yyyy", Locale("id", "ID"))) {
    // customizations
}
EOF

    # Create dummy icons (optional, or copy from somewhere if available)
    # touching files so git adds the folders
    touch "$base_dir/res/mipmap-hdpi/ic_launcher.png"
    touch "$base_dir/res/mipmap-mdpi/ic_launcher.png"
    touch "$base_dir/res/mipmap-xhdpi/ic_launcher.png"
    touch "$base_dir/res/mipmap-xxhdpi/ic_launcher.png"
    touch "$base_dir/res/mipmap-xxxhdpi/ic_launcher.png"

    echo "Extension files created."
fi

# Add changes to git
git add "$base_dir"

# Commit changes if there are any
if git diff --cached --quiet; then
    echo "No changes to commit."
else
    commit_message="Add new extension: ${ext_name}"
    git config --global user.email "actions@github.com"
    git config --global user.name "GitHub Actions"
    git commit -m "${commit_message}"

    # Push changes to the repository
    git push origin main
fi
