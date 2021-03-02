module namespace local = "local" ;
import module namespace Session = 'http://basex.org/modules/session';
(:~ declare
%rest:path('/index')
%output:method('xml')
function test:index() {
    <div>
        <current>{user:current()}</current>
        <id>{session:id()}</id>
        <session-get>{session:get(session:id())}</session-get>
        <created>{session:created()}</created>
        <list-details>{user:list-details()}</list-details>
    </div>
};

declare
%rest:path('/index/new')
%output:method('html')
%output:html-version('5.0')
function test:new() {
<html>
    <head></head>
    <body>
        <form action="create-user" method="POST">
            <input type="text" placeholder="enter user name" name="user" required="true"/>
            <input type="text" placeholder="enter password" name="pwd" required="true"/>
            <input type='submit' value='créer'/>
        </form>
    </body>
</html>
};

declare
%rest:POST
%rest:path('/index/create-user')
%rest:query-param('user', '{$user}')
%rest:query-param('pwd', '{$pwd}')
%updating
function test:create-user($user, $pwd) {
    user:create($user, $pwd, 'read'),
    update:output(web:redirect('/index/login'))
(:<html>
    <head></head>
    <body>
        <h1>{$user}</h1>
    </body>
</html>:)
};

declare
%rest:path('/index/login')
%output:method('html')
%output:html-version('5.0')
function test:login() {
<html>
    <head></head>
    <body>
        <ul>
            {for $i in user:list()
            return <li>{$i}</li>}
        </ul>
        <form action="login-check" method="POST">
            <input type="text" placeholder="enter user name" name="user" required="true"/>
            <input type="text" placeholder="enter password" name="pwd" required="true"/>
            <input type='submit' value='Login'/>
        </form>
    </body>
</html>
};

declare
%rest:POST
%rest:path('/index/login-check')
%rest:query-param('user', '{$user}')
%rest:query-param('pwd', '{$pwd}')
function test:login-check($user, $pwd) {
    try {
        user:check($user, $pwd),
        session:set('id', $user),
        web:redirect("/index")
    }
    catch user:* {
        web:redirect("/")
    }
};


declare
  %rest:path("/index/logout")
function test:logout() {
  session:delete("id"),
  web:redirect("/index/login")
}; ~:)


(:~ Login page (visible to everyone). :)
declare
  %rest:path("/login")
  %output:method("html")
function local:login() {
  <html>
    Please log in:
    <form action="/login-check" method="post">
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
function local:main() {
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
function local:admin() {
  <html>
    Welcome to the admin page. You are {fn:string(user:list-details(Session:get('id'))/@name)}
  </html>
};


(:~
 : Global permission checks.
 : Rejects any usage of the HTTP DELETE method.
 :)
declare %perm:check %rest:DELETE function local:check() {
  error((), 'Access denied to DELETE method.')
};

(:~
 : Permission check: Area for logged-in users.
 : Checks if a session id exists for the current user; if not, redirects to the login page.
 :)
declare %perm:check('/main') function local:check-app() {
  let $user := Session:get('id')
  where empty($user)
  return web:redirect('/')
};

(:~
 : Permissions: Admin area.
 : Checks if the current user is admin; if not, redirects to the main page.
 : @param $perm  map with permission data
 :)
declare %perm:check('/main/admin', '{$perm}') function local:check-admin($perm) {
  let $user := Session:get('id')
  where not(user:list-details($user)/@permission = $perm?allow)
  return web:redirect('/main')
};

declare
  %rest:path("/login-check")
  %rest:query-param("name", "{$name}")
  %rest:query-param("pass", "{$pass}")
function local:login($name, $pass) {
  try {
    user:check($name, $pass),
    Session:set('id', $name),
    web:redirect("/main")
  } catch user:* {
    web:redirect("/")
  }
};

declare
  %rest:path("/logout")
function local:logout() {
  Session:delete('id'),
  web:redirect("/")
};
