-- создаю отдельные представления для расчета показателей, которые потом соеденью в общем запросе
with 
-- список созданных, но отмененных заказов
t0 as (SELECT order_id
        FROM   user_actions
        WHERE  action = 'cancel_order'), 
        
--Джойн orders и products. Таблица с заказами, их товарами и информацией о ценнах и налогах
t1 as (SELECT date,
       order_id,
       name,
       price,
       nds,
       round(price_before_nds, 2) as price_before_nds,
       round(nds_price, 2) as nds_price
    FROM   (SELECT creation_time::date as date,
               order_id,
               product_ids,
               unnest(product_ids) as product_id
        FROM   orders
        WHERE  order_id not in (SELECT order_id
                                FROM   user_actions
                                WHERE  action = 'cancel_order')) as a
    LEFT JOIN (SELECT product_id,
                      price,
                      name,
                      case when name in ('сахар', 'сухарики', 'сушки', 'семечки', 'масло льняное', 'виноград',
                                         'масло оливковое', 'арбуз', 'батон', 'йогурт', 'сливки',
                                         'гречка', 'овсянка', 'макароны', 'баранина', 'апельсины',
                                         'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 'мука',
                                         'шпроты', 'сосиски', 'свинина', 'рис', 'масло кунжутное',
                                         'сгущенка', 'ананас', 'говядина', 'соль', 'рыба вяленая',
                                         'масло подсолнечное', 'яблоки', 'груши', 'лепешка', 'молоко',
                                         'курица', 'лаваш', 'вафли', 'мандарины') then 10
                           else 20 end as nds,
                      case when name in ('сахар', 'сухарики', 'сушки', 'семечки', 'масло льняное', 'виноград',
                                         'масло оливковое', 'арбуз', 'батон', 'йогурт', 'сливки',
                                         'гречка', 'овсянка', 'макароны', 'баранина', 'апельсины',
                                         'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 'мука',
                                         'шпроты', 'сосиски', 'свинина', 'рис', 'масло кунжутное',
                                         'сгущенка', 'ананас', 'говядина', 'соль', 'рыба вяленая',
                                         'масло подсолнечное', 'яблоки', 'груши', 'лепешка', 'молоко',
                                         'курица', 'лаваш', 'вафли', 'мандарины') then price::decimal/110*100
                           else price::decimal/120*100 end as price_before_nds,
                      case when name in ('сахар', 'сухарики', 'сушки', 'семечки', 'масло льняное', 'виноград',
                                         'масло оливковое', 'арбуз', 'батон', 'йогурт', 'сливки',
                                         'гречка', 'овсянка', 'макароны', 'баранина', 'апельсины',
                                         'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 'мука',
                                         'шпроты', 'сосиски', 'свинина', 'рис', 'масло кунжутное',
                                         'сгущенка', 'ананас', 'говядина', 'соль', 'рыба вяленая',
                                         'масло подсолнечное', 'яблоки', 'груши', 'лепешка', 'молоко',
                                         'курица', 'лаваш', 'вафли', 'мандарины') then price::decimal/110*10
                           else price::decimal/120*20 end as nds_price
               FROM   products) as b using (product_id)),
               
--Доходы: общая выручка за каждый день
t2 as (SELECT date,
        count(distinct order_id) as orders_count,
        sum(price) as revenue,
        sum(price_before_nds) as revenue_before_nds,
        sum(nds_price) as tax
    FROM   t1
    GROUP BY date
    ORDER BY date),
    
--Расходы: сборы и доставка заказов
t3 as (SELECT order_id,
         creation_date,
         deliver_date,
         courier_id,
         assembly_cost,
         deliver_cost
  FROM   (SELECT creation_time::date as creation_date,
                 order_id,
                 case when date_part('month', creation_time) = 8 then 140
                      when date_part('month', creation_time) = 9 then 115 end as assembly_cost
          FROM   orders
          WHERE  order_id not in (SELECT order_id
                                  FROM   user_actions
                                  WHERE  action = 'cancel_order')) as a
      LEFT JOIN (SELECT time::date as deliver_date,
                        order_id,
                        courier_id,
                        150 as deliver_cost
                 FROM   courier_actions
                 WHERE  action = 'deliver_order') as b using (order_id)
  ORDER BY order_id),
  
--Расходы: подсчет расходов на каждого курьера
t4 as (SELECT courier_id,
            deliver_date,
            sum(deliver_cost) as deliver_cost_per_day,
            count(distinct order_id) as orders_count_per_day,
            case when count(distinct order_id) >= 5 and
                      date_part('month', deliver_date) = 8 then 400
                 when count(distinct order_id) >= 5 and
                      date_part('month', deliver_date) = 9 then 500
                 else 0 end as bonus_per_day,
            sum(deliver_cost) + case when count(distinct order_id) >= 5 and
                                          date_part('month', deliver_date) = 8 then 400
                                     when count(distinct order_id) >= 5 and
                                          date_part('month', deliver_date) = 9 then 500
                                     else 0 end as courier_salary_per_day
     FROM   t3
     GROUP BY courier_id, deliver_date),
     
--Расходы: подсчет расходов каждый день
t5 as (SELECT creation_date as date,
             day_assembly_cost,
             rent_per_day,
             total_salary_per_day,
             day_assembly_cost + rent_per_day + total_salary_per_day as costs
      FROM   (SELECT creation_date,
                     sum(assembly_cost) as day_assembly_cost,
                     case when date_part('month', creation_date) = 8 then 120000
                          when date_part('month', creation_date) = 9 then 150000 end as rent_per_day
              FROM   t3
              GROUP BY creation_date) as a join (SELECT deliver_date,
                                                sum(courier_salary_per_day) as total_salary_per_day
                                         FROM   t4
                                         GROUP BY deliver_date) as b
              ON creation_date = deliver_date
      ORDER BY date)
      
--Основной запрос
SELECT date,
       revenue,
       costs,
       tax,
       revenue_before_nds - costs as gross_profit,
       sum(revenue) OVER (ORDER BY date) as total_revenue,
       sum(costs) OVER (ORDER BY date) as total_costs,
       sum(tax) OVER (ORDER BY date) as total_tax,
       sum(revenue_before_nds - costs) OVER (ORDER BY date) as total_gross_profit,
       round((revenue_before_nds - costs)::decimal/revenue*100, 2) as gross_profit_ratio,
       round((sum(revenue_before_nds - costs) OVER (ORDER BY date))::decimal/ (sum(revenue) OVER (ORDER BY date))*100,
             2) as total_gross_profit_ratio
FROM   t2 join t5 using (date)
ORDER BY date
