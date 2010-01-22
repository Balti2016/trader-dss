<?php
// This script displays the login screen, sets the session cookie with the username and uid then redirects to the profile admin page
require 'HTML/QuickForm.php';
@include("checks.php");
redirect_login_pf();    # start session and redirect depending on cookie values

function check_account($v)
{
    // this function is called with the username and password in the array $v
    // validate the account details from the database
    global $result;
    $username = $v[0];
    $passwd = $v[1];
    $conn=pg_connect("host=localhost dbname=trader user=postgres password=happy") or die(pg_last_error($conn));
    $query = "select uid, name, passwd from users where name = '$username' and passwd = md5('$passwd')";
    $result = pg_query($conn, $query);
    if (pg_num_rows($result) > 0 )
    {
        $flag = true;
    }
    else
    {
        $flag = false;
    }
    unset($conn);
    return $flag;
}

# create the form and validation rules
$form = new HTML_QuickForm('login');
$form->addElement('header', null, 'Login to the Trader DSS. Authorised users only');
$form->addElement('text', 'username', 'Username:', array('size' => 30, 'maxlength' => 100));
$form->addRule('username', 'Please enter your username', 'required');
$form->addElement('password', 'passwd', 'Password:', array('size' => 10, 'maxlength' => 100));
$form->addRule(array('username', 'passwd'), 'Account details incorrect', 'callback', 'check_account');
$form->addRule('passwd', 'Must enter a password', 'required');
$form->addElement('submit', 'login', 'Login');
$result = ''; # this is nasty, it's populated by check_accounts to avoid querying the DB twice
if ($form->validate())
{
    $form->freeze();
    $_SESSION['username'] = pg_fetch_result($result, 0, 'name');
    $_SESSION['uid'] = pg_fetch_result($result, 0, 'uid');
    redirect_login_pf();
}
else
{
    $form->display();
}
?>
