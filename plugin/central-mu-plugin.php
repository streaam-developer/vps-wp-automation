<?php
/*
Plugin Name: Central Must-Use Plugin
Description: A central plugin that applies to all domains
Version: 1.0
*/

// Add your custom code here

// Example: Disable XML-RPC for security
add_filter( 'xmlrpc_enabled', '__return_false' );

// Example: Remove WordPress version from head
remove_action('wp_head', 'wp_generator');

// You can add more customizations here