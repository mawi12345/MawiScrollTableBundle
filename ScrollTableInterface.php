<?php
namespace Mawi\Bundle\ScrollTableBundle;

interface ScrollTableInterface
{
	public function getRows($start = 0, $end = 0, $orderBy = array(), $filter = array());
	public function getRowCount($filter = array());
}