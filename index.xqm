module namespace test = "test" ;

declare
%rest:path('/index')
%output:method('xml')
function test:index() {
    <current>{user:current()}</current>
    <id>{session:id()}</id>
    <created>{session:created()}</created>
    <div>{user:list-details()}</div>
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
};
