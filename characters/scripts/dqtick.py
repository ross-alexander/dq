# ----------------------------------------------------------------------
#
# cal_cdate
#
# Code taken from Tick.pm but fix handling of old AP dates
#
# ----------------------------------------------------------------------

class Tick:
    def struct(self):
        tick = self.tick
        if self.calendar == 'WK':
            year = int(tick/364)
            tick = tick - year * 364
            quarter = int(tick/91)
            tick = tick - quarter * 91
            month = quarter*3 + int((tick-1)/30)
            day = tick - (month%3)*30
            res = {
                'calendar': self.calendar,
                'year': year + 770,
                'month': month+1,
                'day': day,
            }
            if day == 0:
                quarter = int(month/4)
                res['quarter'] = quarter
                inter_cal_days = ('Beltane', 'Lugnasad', 'Samhain', 'Candlemansa')
                res['inter_calendar_day'] = inter_cal_days[quarter]
            months = ('Meadow', 'Heat', 'Breeze', 'Fruit', 'Harvest', 'Vintage', 'Frost', 'Snow', 'Ice', 'Thaw', 'Seedtime', 'Blossom');
            res['month_name'] = months[month]
        if self.calendar == 'AP':
            tick = tick - 273
            year = int(tick/364)
            tick = tick - year*364
            month_day = (0, 31, 59, 89, 120, 151, 181, 212, 243, 273, 304, 334)
            for m in range(0, 12):
                if tick >= month_day[11 - m]:
                    month = 11 - m
                    break
            day = tick - month_day[month]
            res = {
                'calendar': self.calendar,
                'year': year + 1970,
                'month': month+1,
                'day': day+1
            }
        return res

    def mdate(self):
        sep = "."
        s = self.struct()
        return "%s%s%s%s%s %s" % (s['day'], sep, s['month'], sep, s['year'], s['calendar'])
            
    def cdate(self):
        tick = self.tick
        s = self.struct()
        res = ''
        if self.calendar == 'WK':
            year = s['year']
            month = s['month'] - 1
            day = s['day']
            if s['day'] == 0:
                quarter = int(month/4)
                inter_cal_days = ('Beltane', 'Lugnasad', 'Samhain', 'Candlemansa')
                res = "%s %d WK" % (inter_cal_days[quarter], year)
            else:
                months = ('Meadow', 'Heat', 'Breeze', 'Fruit', 'Harvest', 'Vintage', 'Frost', 'Snow', 'Ice', 'Thaw', 'Seedtime', 'Blossom');
                res = "%s %d, %d WK" % (months[month], day, year);
        if self.calendar == 'AP':
            year = s['year']
            month = s['month'] - 1
            day = s['day']
            month_name = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')
            res = "%s %d, %d AP" % (month_name[month], day, year)
        return res

    def __init__(self, tick):
        if (isinstance(tick, int)):
            self.tick = tick
            self.calendar = 'WK'
        elif isinstance(tick, Tick):            
            self.tick = tick.tick
            self.calendar = tick.calendar
        elif isinstance(tick, str):
            self.tick = str2tick(tick)
        elif isinstance(tick, dict):
            self.tick = tick['tick']
            self.calendar = tick['calendar']
            
        
