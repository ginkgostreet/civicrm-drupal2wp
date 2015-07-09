-- delete non-users
DELETE FROM hbl39702_civicrm.civicrm_uf_match
WHERE uf_name NOT IN
(SELECT wp.user_email
FROM  hbl39702_wp_dev.cyclewp_users `wp`
INNER JOIN hbl39702_drupal_dev.users `d`
ON wp.user_email = d.mail);

-- update the UF match table with WP IDs
UPDATE hbl39702_civicrm.civicrm_uf_match `match`
INNER JOIN hbl39702_wp_dev.cyclewp_users `wp`
ON match.uf_name = wp.user_email
SET match.uf_id = wp.id;
