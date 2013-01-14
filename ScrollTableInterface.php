<?php
namespace Mawi\Bundle\ScrollTableBundle;

interface ScrollTableInterface
{
	public function getPage($num, $orderBy = '', $filter = '');
	public function getPageCount($filter = '');
}