-- #########################################################
-- ## Black Sun Defense 
-- ## by bb.figueiredo@gmail.com
-- ## 04/07/2008 (dd/mm/yy)
-- ##
-- ## Check the main script for more information.
-- ##
-- #########################################################
options = 
{
	{ 
		default = 1, 
		label = "Difficulty", 
		help = "Select the difficulty of the map.", 
		key = 'difficultyAdjustment', 
		pref = 'difficultyAdjustment', 
		values = { 
			{text = "Normal", help = "Default", key = 0.5, }, 

			{text = "Incredibly Easy", help = "", key = 0.1, }, 
			{text = "Very Easy", help = "", key = 0.25, }, 
			{text = "Easy", help = "", key = 0.4, }, 

			{text = "Hard", help = "", key = 0.6, }, 
			{text = "Very Hard", help = "", key = 0.75, }, 
			{text = "Incredibly Hard", help = "", key = 1, }, 
		}, 
	}, 
	{ 
		default = 1, 
		label = "Startup Time", 
		help = "Select how much time you will have before the gates activate.", 
		key = 'startupDelay', 
		pref = 'startupDelay', 
		values = { 
			{text = "2.5 minutes", help = "Default", key = 150, }, 

			{text = "1 minute", help = "", key = 60, }, 
			{text = "1.5 minutes", help = "", key = 90, }, 
			{text = "2 minutes", help = "", key = 120, }, 

			{text = "3 minutes", help = "", key = 180, }, 
			{text = "5 minutes", help = "", key = 300, }, 
			{text = "10 minutes", help = "", key = 600, }, 
		}, 
	}, 
};
