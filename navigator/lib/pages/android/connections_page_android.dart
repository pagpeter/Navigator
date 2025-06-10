import 'package:flutter/material.dart';
import 'package:navigator/models/station.dart';
import 'package:navigator/pages/page_models/connections_page.dart';
import 'package:navigator/pages/page_models/home_page.dart';

class ConnectionsPageAndroid extends HomePage
{
  ConnectionsPageAndroid(this.page, this.to, {super.key});

  ConnectionsPage page;
  Station to;
  
  @override
  Widget build(BuildContext context) {
    return Text(
      to.name
    );
  }
}
