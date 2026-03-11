select g.*
from {{ ref('gld_daily_revenue') }} g
left join {{ ref('country_reference') }} c
  on g.country = c.country
where g.country is not null
  and c.country is null
