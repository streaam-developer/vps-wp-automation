<?php
/**
 * Plugin Name: Conditional Ads Loader
 * Plugin URI: https://example.com/conditional-ads-loader
 * Description: Loads ads scripts conditionally based on domain.
 * Version: 1.0.0
 * Author: Your Name
 * License: GPL v2 or later
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain: conditional-ads-loader
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

class ConditionalAdsLoader {

    public function __construct() {
        add_action('wp_enqueue_scripts', array($this, 'enqueue_scripts'));
        add_action('wp_head', array($this, 'output_head_scripts'));
        add_action('wp_footer', array($this, 'output_body_scripts'));
        add_action('admin_menu', array($this, 'add_admin_menu'));
        add_action('admin_init', array($this, 'register_settings'));
    }

    private function get_config() {
        $github_url = get_option('cal_github_config_url', '');
        if (!empty($github_url)) {
            $response = wp_remote_get($github_url);
            if (!is_wp_error($response) && wp_remote_retrieve_response_code($response) == 200) {
                $body = wp_remote_retrieve_body($response);
                $config = json_decode($body, true);
                if (json_last_error() === JSON_ERROR_NONE && isset($config['rules'])) {
                    return $config['rules'];
                }
            }
        }
        // Fallback to local options - convert to rules format
        $rules = array();
        $head_domains = array_map('trim', explode(',', get_option('cal_head_domains', 'themovlesflix.info,themovlesflix.online,movlesflix.info,skybap.shop')));
        if (!empty($head_domains)) {
            $rules[] = array(
                'domains' => $head_domains,
                'placement' => 'head',
                'script_type' => 'external',
                'script_content' => get_option('cal_head_script_url', 'https://sads.adsboosters.xyz/ba8d9dd35268014c09031a8c587cf84e.js')
            );
        }
        $body_domains = array_map('trim', explode(',', get_option('cal_body_domains', 'biharbhumi.info.in,yojana11.com,niveshskill.com,tessofficial.com')));
        if (!empty($body_domains)) {
            $rules[] = array(
                'domains' => $body_domains,
                'placement' => 'body',
                'script_type' => 'inline',
                'script_content' => get_option('cal_body_script_inline', '')
            );
        }
        return $rules;
    }

    public function enqueue_scripts() {
        $current_domain = parse_url(home_url(), PHP_URL_HOST);
        $rules = $this->get_config();

        foreach ($rules as $rule) {
            if (in_array($current_domain, $rule['domains']) && $rule['script_type'] === 'external') {
                $in_footer = ($rule['placement'] === 'body');
                wp_enqueue_script('ads-' . md5($rule['script_content']), $rule['script_content'], array(), null, $in_footer);
            }
        }
    }

    public function output_head_scripts() {
        $current_domain = parse_url(home_url(), PHP_URL_HOST);
        $rules = $this->get_config();

        foreach ($rules as $rule) {
            if (in_array($current_domain, $rule['domains']) && $rule['placement'] === 'head' && $rule['script_type'] === 'inline' && !empty($rule['script_content'])) {
                echo $rule['script_content'];
            }
        }
    }


    public function output_body_scripts() {
        $current_domain = parse_url(home_url(), PHP_URL_HOST);
        $rules = $this->get_config();

        foreach ($rules as $rule) {
            if (in_array($current_domain, $rule['domains']) && $rule['placement'] === 'body' && $rule['script_type'] === 'inline' && !empty($rule['script_content'])) {
                echo $rule['script_content'];
            }
        }
    }

    public function add_admin_menu() {
        add_options_page('Conditional Ads Loader', 'Conditional Ads Loader', 'manage_options', 'conditional-ads-loader', array($this, 'settings_page'));
    }

    public function register_settings() {
        register_setting('conditional_ads_loader_group', 'cal_github_config_url');
        register_setting('conditional_ads_loader_group', 'cal_head_domains');
        register_setting('conditional_ads_loader_group', 'cal_body_domains');
        register_setting('conditional_ads_loader_group', 'cal_head_script_url');
        register_setting('conditional_ads_loader_group', 'cal_body_script_inline');
    }

    public function settings_page() {
        ?>
        <div class="wrap">
            <h1>Conditional Ads Loader Settings</h1>
            <form method="post" action="options.php">
                <?php settings_fields('conditional_ads_loader_group'); ?>
                <?php do_settings_sections('conditional_ads_loader_group'); ?>
                <table class="form-table">
                    <tr valign="top">
                        <th scope="row">GitHub Config URL (JSON)</th>
                        <td><input type="text" name="cal_github_config_url" value="<?php echo esc_attr(get_option('cal_github_config_url', 'https://raw.githubusercontent.com/streaam-developer/central-config-repo/main/config.json')); ?>" placeholder="https://raw.githubusercontent.com/user/repo/main/config.json" /></td>
                    </tr>
                    <tr valign="top">
                        <th scope="row">Head Domains (comma separated)</th>
                        <td><input type="text" name="cal_head_domains" value="<?php echo esc_attr(get_option('cal_head_domains', 'themovlesflix.info,themovlesflix.online,movlesflix.info,skybap.shop')); ?>" /></td>
                    </tr>
                    <tr valign="top">
                        <th scope="row">Head Script URL</th>
                        <td><input type="text" name="cal_head_script_url" value="<?php echo esc_attr(get_option('cal_head_script_url', 'https://sads.adsboosters.xyz/ba8d9dd35268014c09031a8c587cf84e.js')); ?>" /></td>
                    </tr>
                    <tr valign="top">
                        <th scope="row">Body Domains (comma separated)</th>
                        <td><input type="text" name="cal_body_domains" value="<?php echo esc_attr(get_option('cal_body_domains', 'biharbhumi.info.in,yojana11.com,niveshskill.com,tessofficial.com')); ?>" /></td>
                    </tr>
                    <tr valign="top">
                        <th scope="row">Body Script Inline</th>
                        <td><textarea name="cal_body_script_inline" rows="10" cols="50"><?php echo esc_textarea(get_option('cal_body_script_inline', '<script data-cfasync="false" type="text/javascript" id="clever-core">
/* <![CDATA[ */
    (function (document, window) {
        var a, c = document.createElement("script"), f = window.frameElement;

        c.id = "CleverCoreLoader98923";
        c.src = "https://scripts.cleverwebserver.com/94fb25de29c41081a956ec738a8faedf.js";

        c.async = !0;
        c.type = "text/javascript";
        c.setAttribute("data-target", window.name || (f && f.getAttribute("id")));
        c.setAttribute("data-callback", "put-your-callback-function-here");
        c.setAttribute("data-callback-url-click", "put-your-click-macro-here");
        c.setAttribute("data-callback-url-view", "put-your-view-macro-here");

        try {
            a = parent.document.getElementsByTagName("script")[0] || document.getElementsByTagName("script")[0];
        } catch (e) {
            a = !1;
        }

        a || (a = document.getElementsByTagName("head")[0] || document.getElementsByTagName("body")[0]);
        a.parentNode.insertBefore(c, a);
    })(document, window);
/* ]]> */
</script>')); ?></textarea></td>
                    </tr>
                </table>
                <?php submit_button(); ?>
            </form>
        </div>
        <?php
    }
}

// Initialize the plugin
new ConditionalAdsLoader();
?>