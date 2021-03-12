xquery version '3.0' ;
module namespace xpr.session = "xpr.session" ;
(:~
 : This xquery module is an application for xpr
 :
 : @author emchateau & sardinecan (ANR Experts)
 : @since 2019-01
 : @licence GNU http://www.gnu.org/licenses
 : @version 0.2
 :
 : xpr is free software: you can redistribute it and/or modify
 : it under the terms of the GNU General Public License as published by
 : the Free Software Foundation, either version 3 of the License, or
 : (at your option) any later version.
 :
 :)
import module namespace Session = 'http://basex.org/modules/session';

import module namespace xpr.xpr = 'xpr.xpr' at '../xpr/xpr.xqm' ;
import module namespace G = 'xpr.globals' at '../xpr/globals.xqm' ;
import module namespace xpr.mappings.html = 'xpr.mappings.html' at '../xpr/mappings.html.xqm' ;
import module namespace xpr.models.xpr = 'xpr.models.xpr' at '../xpr/models.xpr.xqm' ;
import module namespace xpr.models.networks = 'xpr.models.networks' at '../xpr/models.networks.xqm' ;

declare namespace rest = "http://exquery.org/ns/restxq" ;
declare namespace file = "http://expath.org/ns/file" ;
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization" ;
declare namespace db = "http://basex.org/modules/db" ;
declare namespace web = "http://basex.org/modules/web" ;
declare namespace update = "http://basex.org/modules/update" ;
declare namespace perm = "http://basex.org/modules/perm" ;
declare namespace user = "http://basex.org/modules/user" ;
declare namespace session = 'http://basex.org/modules/session' ;
declare namespace http = "http://expath.org/ns/http-client" ;

declare namespace ev = "http://www.w3.org/2001/xml-events" ;
declare namespace eac = "eac" ;

declare namespace map = "http://www.w3.org/2005/xpath-functions/map" ;
declare namespace xf = "http://www.w3.org/2002/xforms" ;
declare namespace xlink = "http://www.w3.org/1999/xlink" ;

declare namespace xpr = "xpr" ;
declare default element namespace "xpr" ;
declare default function namespace "xpr.xpr" ;

declare default collation "http://basex.org/collation?lang=fr" ;


(:~ Login page (visible to everyone). :)
declare
  %rest:path("xpr/login")
  %output:method("html")
function xpr.session:login() {
  <html>
    Please log in:
    <form action="/xpr/login/check" method="post">
      <input name="name"/>
      <input type="password" name="pass"/>
      <input type="submit"/>
    </form>
  </html>
};

(:~ Main page (restricted to logged in users). :)
declare
  %rest:path("/main")
  %output:method("html")
function xpr.session:main() {
  <html>
    Welcome to the main page:
    <a href='/main/admin'>admin area</a>,
    <a href='/logout'>log out</a>.
  </html>
};

(:~ Admin page. :)
declare
  %rest:path("/main/admin")
  %output:method("html")
  %perm:allow("admin")
function xpr.session:admin() {
  <html>
    Welcome to the admin page. You are {fn:string(user:list-details(Session:get('id'))/@name)}
  </html>
};

(:~ Admin page. :)
declare
  %rest:path("/who")
  %output:method("html")
function xpr.session:who() {
  <html>
    Welcome to the who page. You are
    <code>{user:list-details(Session:get('id'))}</code>
  </html>
};

(:~
 : Global permission checks.
 : Rejects any usage of the HTTP DELETE method.
 :)
declare
    %perm:check
    %rest:DELETE
function xpr.session:check() {
  fn:error((), 'Access denied to DELETE method.')
};

(:~
 : Permission check: Area for logged-in users.
 : Checks if a session id exists for the current user; if not, redirects to the login page.
 :)
declare
    %perm:check('/main')
function xpr.session:check-app() {
  let $user := Session:get('id')
  where fn:empty($user)
  return web:redirect('/')
};

(:~
 : Permissions: Admin area.
 : Checks if the current user is admin; if not, redirects to the main page.
 : @param $perm map with permission data
 :)
declare
    %perm:check('/main/admin', '{$perm}')
function xpr.session:check-admin($perm) {
  let $user := Session:get('id')
  where fn:not(user:list-details($user)/@permission = $perm?allow)
  return web:redirect('/main')
};

(:~
 : Permissions: Admin area.
 : Checks if the current user is admin; if not, redirects to the main page.
 : @param $perm map with permission data
 :)
declare
    %perm:check('xpr/expertises/new', '{$perm}')
function xpr.session:checkExpertiseRight($perm) {
  let $user := Session:get('id')
  where fn:empty($user) or fn:not(user:list-details($user)/*:info/*:grant/@type = $perm?allow)
  return web:redirect('/xpr/login')
};

declare
  %rest:path("xpr/login/check")
  %rest:query-param("name", "{$name}")
  %rest:query-param("pass", "{$pass}")
function xpr.session:login($name, $pass) {
  try {
    user:check($name, $pass),
    Session:set('id', $name),
    web:redirect("/main")
  } catch user:* {
    web:redirect("/")
  }
};

declare
  %rest:path("xpr/logout")
function xpr.session:logout() {
  Session:delete('id'),
  web:redirect("/")
};

(:~
 : This function creates a new user
 : @return an xforms to create a new user
:)
declare
  %rest:path("xpr/users/new")
  %output:method("xml")
function xpr.session:newUser() {
  let $content := map {
    'instance' : '',
    'model' : 'xprUserModel.xml',
    'trigger' : '',
    'form' : 'xprUserForm.xml'
  }
  let $outputParam := map {
    'layout' : "template.xml"
  }
  return
    (processing-instruction xml-stylesheet { fn:concat("href='", $G:xsltFormsPath, "'"), "type='text/xsl'"},
    <?css-conversion no?>,
    xpr.models.xpr:wrapper($content, $outputParam)
    )
};

(:~
 : This function creates new user
 :)
declare
  %rest:path("xpr/users/put")
  %output:method("xml")
  %rest:header-param("Referer", "{$referer}", "none")
  %rest:PUT("{$param}")
  %updating
function xpr.session:putUser($param, $referer) {
  let $db := db:open("xpr")
  let $user := $param
  let $userName := fn:normalize-space($user/*:user/*:name)
  let $userPwd := fn:normalize-space($user/*:user/*:password)
  let $userPermission := fn:normalize-space($user/*:user/*:permission)
  let $userInfo :=
    <info xmlns="">{
        for $right in $user/*:user/*:info/*:grant
        return <grant type="{$right/@type}">{fn:normalize-space($right)}</grant>
    }</info>
  return
    user:create(
      $userName,
      $userPwd,
      $userPermission,
      'xpr',
      $userInfo)
};
