import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:async';
import 'BooruHandler.dart';
import 'BooruItem.dart';
import 'Booru.dart';
/**
 * Booru Handler for the Shimmie engine
 */
class ShimmieHandler extends BooruHandler{
  List<BooruItem> fetched = new List();
  bool tagSearchEnabled = false;
  // Dart constructors are weird so it has to call super with the args
  ShimmieHandler(Booru booru,int limit) : super(booru,limit);

  /**
   * This function will call a http get request using the tags and pagenumber parsed to it
   * it will then create a list of booruItems
   */
  Future Search(String tags,int pageNum) async{
    if(this.pageNum == pageNum){
      return fetched;
    }
    this.pageNum = pageNum;
    if (prevTags != tags){
      fetched = new List();
    }
    String url = makeURL(tags);
    print(url);
    try {
      final response = await http.get(url,headers: {"Accept": "text/html,application/xml",  "user-agent":"LoliSnatcher_Droid/1.6.0"});
      // 200 is the success http response code
      if (response.statusCode == 200) {
        var parsedResponse = xml.parse(response.body);
        /**
         * This creates a list of xml elements 'post' to extract only the post elements which contain
         * all the data needed about each image
         */
        var posts = parsedResponse.findAllElements('post');
        // Create a BooruItem for each post in the list
        for (int i =0; i < posts.length; i++){
          var current = posts.elementAt(i);
          /**
           * Add a new booruitem to the list .getAttribute will get the data assigned to a particular tag in the xml object
           */
          if (!booru.baseURL.contains("https://whyneko.com/booru")){
            fetched.add(new BooruItem(current.getAttribute("file_url"),current.getAttribute("preview_url"),current.getAttribute("preview_url"),current.getAttribute("tags").split(" "),makePostURL(current.getAttribute("id"))));
          } else {
            String cutURL = booru.baseURL.split("/booru")[0];
            fetched.add(new BooruItem(cutURL+current.getAttribute("file_url"),cutURL+current.getAttribute("preview_url"),cutURL+current.getAttribute("preview_url"),current.getAttribute("tags").split(" "),makePostURL(current.getAttribute("id"))));
          }

        }
        prevTags = tags;
        return fetched;
      }
    } catch(e) {
      print(e);
      return fetched;
    }

  }
  // This will create a url to goto the images page in the browser
  String makePostURL(String id){
    return "${booru.baseURL}/post/view/$id";
  }
  // This will create a url for the http request
  String makeURL(String tags){
    return "${booru.baseURL}/api/danbooru/find_posts/index.xml?&tags=$tags&limit=${limit.toString()}&page=${pageNum.toString()}";
  }


  String makeTagURL(String input){
    return "${booru.baseURL}/tags.json?search[name_matches]=$input*&limit=5";
  }
  //No api documentation on finding tags
  @override
  Future tagSearch(String input) async {
    List<String> searchTags = new List();
    return searchTags;
  }
}