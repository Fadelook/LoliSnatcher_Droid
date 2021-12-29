import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'package:LoliSnatcher/SearchGlobals.dart';
import 'package:LoliSnatcher/widgets/MarqueeText.dart';
import 'package:LoliSnatcher/SettingsHandler.dart';
import 'package:LoliSnatcher/widgets/CachedFavicon.dart';

class TabBox extends StatelessWidget {
  final SearchHandler searchHandler = Get.find<SearchHandler>();
  final SettingsHandler settingsHandler = Get.find<SettingsHandler>();

  final GlobalKey dropdownKey = GlobalKey();
  GestureDetector? detector;

  // TODO fix this
  // dropdownbutton small clickable zone workaround when using inputdecoration
  // code from: https://github.com/flutter/flutter/issues/53634
  void openItemsList() {
    void search(BuildContext? context) {
      context?.visitChildElements((element) {
        if (detector != null) return;
        if (element.widget != null && element.widget is GestureDetector)
          detector = element.widget as GestureDetector;
        else
          search(element);
      });
    }

    search(dropdownKey.currentContext);
    if (detector != null) detector!.onTap?.call();
  }

  Widget buildRow(SearchGlobal tab) {
    bool isNotEmptyBooru = tab.selectedBooru.value.faviconURL != null;

    // print(value.tags);
    int? totalCount = tab.booruHandler.totalCount.value;
    String totalCountText = (totalCount > 0) ? " ($totalCount)" : "";
    String tagText = "${tab.tags == "" ? "[No Tags]" : tab.tags}$totalCountText";

    return Container(
      width: double.maxFinite,
      height: 30,
      child: Row(
        children: [
          isNotEmptyBooru
            ? (tab.selectedBooru.value.type == "Favourites"
              ? Icon(Icons.favorite, color: Colors.red, size: 18)
              : CachedFavicon(tab.selectedBooru.value.faviconURL!)
            )
            : Icon(CupertinoIcons.question, size: 18),
          const SizedBox(width: 3),
          MarqueeText(
            key: ValueKey(tagText),
            text: tagText,
            fontSize: 16,
            color: tab.tags == "" ? Colors.grey : null,
          ),
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // constraints: settingsHandler.appMode == 'Desktop' ? BoxConstraints(maxHeight: 40, minHeight: 20, minWidth: 100) : null,
      padding: settingsHandler.appMode == 'Desktop' ? EdgeInsets.fromLTRB(2, 5, 2, 2) : EdgeInsets.fromLTRB(5, 8, 5, 8),
      child: Obx(() {
        List<SearchGlobal> list = searchHandler.list;
        int index = searchHandler.currentIndex;

        if(list.length == 0) {
          return const SizedBox();
        }

        return GestureDetector(
          onTap: openItemsList,
          child: DropdownButtonFormField<SearchGlobal>(
            key: dropdownKey,
            isExpanded: true,
            value: list[index],
            icon: Icon(Icons.arrow_drop_down),
            itemHeight: kMinInteractiveDimension,
            decoration: InputDecoration(
              labelText: 'Tab',
              labelStyle: TextStyle(color: Get.theme.colorScheme.onBackground, fontSize: 18),
              // contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              contentPadding: settingsHandler.appMode == 'Desktop' ? EdgeInsets.symmetric(horizontal: 12, vertical: 2) : EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Get.theme.colorScheme.secondary)
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Get.theme.colorScheme.secondary)
              ),
            ),
            dropdownColor: Get.theme.colorScheme.surface,
            onChanged: (SearchGlobal? newValue) {
              searchHandler.searchTextController.text = newValue?.tags ?? ''; // set search box text anyway
              if (newValue != null && list.indexOf(newValue) != index){
                // ...but change tab only if it exists(?) and if it's not a current one
                searchHandler.changeTabIndex(list.indexOf(newValue));
              }
            },
            selectedItemBuilder: (BuildContext context) {
              return list.map<DropdownMenuItem<SearchGlobal>>((SearchGlobal value) {
                return DropdownMenuItem<SearchGlobal>(
                  value: value,
                  child: Container(
                    child: buildRow(value),
                  ),
                );
              }).toList();
            },
            items: list.map<DropdownMenuItem<SearchGlobal>>((SearchGlobal value) {
              bool isCurrent = list.indexOf(value) == index;

              return DropdownMenuItem<SearchGlobal>(
                value: value,
                child: Container(
                  padding: settingsHandler.appMode == 'Desktop' ? EdgeInsets.all(5) : EdgeInsets.fromLTRB(5, 10, 5, 10),
                  decoration: isCurrent
                  ? BoxDecoration(
                    border: Border.all(color: Get.theme.colorScheme.secondary, width: 1),
                    borderRadius: BorderRadius.circular(5),
                  )
                  : null,
                  child: buildRow(value),
                ),
              );
            }).toList(),
          )
        );
      }),
    );
  }
}
