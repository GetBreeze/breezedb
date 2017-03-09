/*
 * MIT License
 *
 * Copyright (c) 2017 Digital Strawberry LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

package tests.migrations
{
	import breezedb.IBreezeDatabase;
	import breezedb.migrations.BreezeMigration;
	
	public class Migration_Insert_Default_Photos extends BreezeMigration
	{

		private const _photos:Array = [
			{ title: "Mountains",   views: 35,  downloads: 10,  likes: 4,  creation_date: new Date(2014, 1, 25) },
			{ title: "Flowers",     views: 6,   downloads: 6,   likes: 6,  creation_date: new Date(2015, 3, 3) },
			{ title: "Lake",        views: 35,  downloads: 0,   likes: 0,  creation_date: new Date(2016, 5, 19) }
		];
		
		public function Migration_Insert_Default_Photos()
		{
			super();
		}
		

		override public function run(db:IBreezeDatabase):void
		{
			db.table("photos").insert(_photos, function(error:Error):void
			{
				done(error == null);
			});
		}
	}
	
}
