#!/bin/bash -e

export APP_NAME=Tethys

function settings_icon {
    parallel --progress -j 0 << EOF
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/settings.imageset/settings@2x.png 48:48
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/settings.imageset/settings@3x.png 72:72
EOF
}

function chevron_icons {
    parallel --progress -j 0 << EOF
svgexport Chevron.xml Chevron@2x.png 48:48
svgexport Chevron.xml Chevron@3x.png 72:72
EOF

    parallel --progress -j 0 << EOF
convert Chevron@2x.png -rotate -90 ../$APP_NAME/Images.xcassets/LeftChevron.imageset/LeftChevron@2x.png
convert Chevron@3x.png -rotate -90 ../$APP_NAME/Images.xcassets/LeftChevron.imageset/LeftChevron@3x.png
convert Chevron@2x.png -rotate 90 ../$APP_NAME/Images.xcassets/RightChevron.imageset/RightChevron@2x.png
convert Chevron@3x.png -rotate 90 ../$APP_NAME/Images.xcassets/RightChevron.imageset/RightChevron@3x.png
EOF
    rm Chevron@2x.png Chevron@3x.png
}

function app_icon {
    parallel --progress -j 0 << EOF
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon@2x.png 120:120
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon@3x.png 180:180
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPadPro@2x.png 167:167
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPad.png 76:76
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-iPad@2x.png 152:152
svgexport AppIcon.xml ../$APP_NAME/Images.xcassets/AppIcon.appiconset/Icon-AppStore.png 1024:1024
EOF
    export ASSET_PATH="../$APP_NAME/Images.xcassets/AppIcon.appiconset"
    parallel --progress -j 0 << EOF
convert $ASSET_PATH/Icon@2x.png -background white -alpha remove $ASSET_PATH/Icon@2x.png
convert $ASSET_PATH/Icon@3x.png -background white -alpha remove $ASSET_PATH/Icon@3x.png
convert $ASSET_PATH/Icon-iPadPro@2x.png -background white -alpha remove $ASSET_PATH/Icon-iPadPro@2x.png
convert $ASSET_PATH/Icon-iPad.png -background white -alpha remove $ASSET_PATH/Icon-iPad.png
convert $ASSET_PATH/Icon-iPad@2x.png -background white -alpha remove $ASSET_PATH/Icon-iPad@2x.png
convert $ASSET_PATH/Icon-AppStore.png -background white -alpha remove $ASSET_PATH/Icon-AppStore.png
EOF
}

function gray_icon {
    export ASSET_PATH="../$APP_NAME/Images.xcassets/GrayIcon.imageset"
    parallel --progress -j 0 << EOF
svgexport GrayIcon.xml $ASSET_PATH/GrayIcon@2x.png 120:120
svgexport GrayIcon.xml $ASSET_PATH/GrayIcon@3x.png 180:180
EOF
}

function markread_icons {
    parallel --progress -j 0 << EOF
svgexport MarkRead.xml ../$APP_NAME/Images.xcassets/MarkRead.imageset/MarkRead.png 25:25
svgexport MarkRead.xml ../$APP_NAME/Images.xcassets/MarkRead.imageset/MarkRead@2x.png 50:50
svgexport MarkRead.xml ../$APP_NAME/Images.xcassets/MarkRead.imageset/MarkRead@3x.png 75:75
svgexport MarkUnread.xml ../$APP_NAME/Images.xcassets/MarkUnread.imageset/MarkUnread.png 25:25
svgexport MarkUnread.xml ../$APP_NAME/Images.xcassets/MarkUnread.imageset/MarkUnread@2x.png 50:50
svgexport MarkUnread.xml ../$APP_NAME/Images.xcassets/MarkUnread.imageset/MarkUnread@3x.png 75:75
EOF
}

if [ $# -eq 1 ]; then
    case "$1" in
        "app") app_icon ;;
        "chevron") chevron_icons ;;
        "gray") gray_icon ;;
        "settings") settings_icon ;;
        "markread") markread_icons ;;
        *)
            echo "Usage: $0 [app, chevron, markread, settings]"
            echo "No arguments will recreate all icons."
            ;;
    esac
else
    export -f app_icon
    export -f chevron_icons
    export -f gray_icon
    export -f settings_icon
    export -f markread_icons 

    parallel --progress -j 0 << EOF
app_icon
chevron_icons
gray_icon
settings_icon
markread_icons
EOF
fi

