--
-- Name: update_exchange_indicators(character varying, date); Type: FUNCTION; Schema: public; Owner: postgres
--      This function could be invoked from the psql command line with something like this
--      select update_exchange_indicators('L', '2010-01-15');
--      to calculate or re-calculate the advance/decline indicators for 'L' (LSE in my case) on the 15th Jan 2010
--
CREATE or replace FUNCTION update_exchange_indicators(new_exch character varying, new_date date) RETURNS void
LANGUAGE plpgsql
AS $$
    -- this function works out some breadth indicators for the exchange on the date given
    DECLARE
        a_d_spread exchange_indicators.adv_dec_spread%TYPE;
        a_d_line exchange_indicators.adv_dec_line%TYPE;
        a_d_ratio exchange_indicators.adv_dec_ratio%TYPE;
        a_ratio exchange_indicators.adv_ratio%TYPE;
        d_ratio exchange_indicators.dec_ratio%TYPE;
        s_ratio exchange_indicators.static_ratio%TYPE;
        t_volume exchange_indicators.volume%TYPE;
        date_volume RECORD;
        adv RECORD;
        dec RECORD;
        static RECORD;
        yesterday RECORD;
    BEGIN
        select count(*) as count into adv from gains where exch = new_exch and date = new_date and gain_1 > 0;
        IF NOT FOUND THEN
            -- do nothing, the gains table is empty
        ELSE
            select count(*) as count into dec from gains where exch = new_exch and date = new_date and gain_1 < 0;
            select count(*) as count into static from gains where exch = new_exch and date = new_date and gain_1 = 0;
            a_d_spread := (adv.count - dec.count);
            If dec.count = 0 THEN
                IF adv.count = 0 THEN
                    -- the first record? No previous day, so no gains
                    a_d_ratio = 0;
                ELSE
                    -- nothing lost any ground? Hard to believe, but that's infinity
                    -- in practise this turns out to be on days when almost nothing trades 
                    --  so you end up with 2 advance and 0 decline which I'm going to round to 0
                    --  since it's not a significant value
                    a_d_ratio = 0;
                END IF;
            ELSE
                a_d_ratio := (adv.count::numeric(9,4) / dec.count::numeric(9,4));
                a_ratio := (adv.count::numeric(9,4) / (adv.count::numeric(9,4) + static.count::numeric(9,4) + dec.count::numeric(9,4)));
                d_ratio := (dec.count::numeric(9,4) / (adv.count::numeric(9,4) + static.count::numeric(9,4) + dec.count::numeric(9,4)));
                s_ratio := (static.count::numeric(9,4) / (adv.count::numeric(9,4) + static.count::numeric(9,4) + dec.count::numeric(9,4)));
            END IF;
            -- find yesterday's adv_dec_line value
            select adv_dec_line as adv_dec_line into yesterday from exchange_indicators where date < new_date and exch = new_exch order by date desc limit 1;
            IF NOT FOUND THEN
                -- this must be the first entry in the exchange_indicators table
                a_d_line := a_d_spread;
            ELSE
                a_d_line := a_d_spread + yesterday.adv_dec_line;
            END IF;
            -- update the exchange_indicators table
            BEGIN
                insert into exchange_indicators ( exch, date, advance, decline, adv_dec_spread, adv_dec_line, adv_dec_ratio, adv_ratio, dec_ratio, static_ratio ) VALUES ( new_exch, new_date, adv.count, dec.count, a_d_spread, a_d_line, a_d_ratio, a_ratio, d_ratio, s_ratio );
            EXCEPTION when unique_violation THEN
                update exchange_indicators set exch = new_exch, date = new_date, advance = adv.count, decline = dec.count, adv_dec_spread = a_d_spread, adv_dec_line = a_d_line, adv_dec_ratio = a_d_ratio, adv_ratio = a_ratio, dec_ratio = d_ratio, static_ratio = s_ratio where date = new_date and exch = new_exch;
            END;
            -- Update the volume with the total number of shares traded on this exchange on this day.
            select sum(volume) as volume into date_volume from quotes where exch = new_exch and date = new_date;
            IF NOT FOUND THEN
                -- nothing found, the date doesn't exist!
                t_volume := 0;
            ELSE
                -- save the date_volume;
                t_volume := date_volume.volume;
            END IF;
            update exchange_indicators set volume = t_volume where exch = new_exch and date = new_date;
        END IF;
    END;
$$;
ALTER FUNCTION public.update_exchange_indicators(new_exch character varying, new_date date) OWNER TO postgres;

--
-- Name: update_all_exchange_indicators(); Type: FUNCTION; Schema: public; Owner: postgres
--      This function could be invoked from the psql command line with something like this
--      select update_all_exchange_indicators();
--      to calculate or re-calculate the advance/decline indicators for all days in the table 
--      trade_dates where the field 'up_to_date' is false. That field is set to false when any quote
--      is added on that date. This is done by the 'update_trade_dates' function called by the trigger
--      on the quotes table.
--
CREATE or replace FUNCTION update_all_exchange_indicators(new_exch character varying) RETURNS void
LANGUAGE plpgsql
AS $$
    -- update all the days where trade_dates.up_to_date is false
    DECLARE
        trade_date RECORD;
    BEGIN
        FOR trade_date IN SELECT exch, date FROM trade_dates WHERE not up_to_date and exch = new_exch ORDER BY date, exch LOOP
            perform update_exchange_indicators(trade_date.exch, trade_date.date);
            -- record that we've made the exchange_indicators up to date
            update trade_dates set up_to_date = TRUE where exch = trade_date.exch and date = trade_date.date;
        END LOOP;
    END;
$$;
ALTER FUNCTION public.update_all_exchange_indicators(new_exch character varying) OWNER TO postgres;
