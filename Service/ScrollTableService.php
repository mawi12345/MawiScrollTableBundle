<?php
namespace Mawi\Bundle\ScrollTableBundle\Service;

use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\DependencyInjection\ContainerAware;
use Sensio\Bundle\FrameworkExtraBundle\Configuration\Route;
use Sensio\Bundle\FrameworkExtraBundle\Configuration\Cache;

/**
 * @author Martin Wind
 */
class ScrollTableService extends ContainerAware
{
	
	private function getServiceName($name)
	{
		return 'scrolltable_'.$name;
	}
	
	private function getTable($name)
	{
		$serviceName = $this->getServiceName($name);
		if (!$this->container->has($serviceName)) throw new NotFoundHttpException('The scrolltable '.$name.' wasn\'t found');
		$table = $this->container->get($serviceName);
		if (!$table instanceof \Mawi\Bundle\ScrollTableBundle\ScrollTableInterface) throw new NotFoundHttpException('The scrolltable '.$name.' dosen\'t implement the ScrollTableInterface');
		return $table;
	}
	
	/**
	 * @Route("/{name}/page/{number}/{order}/{filter}", defaults={"filter" = "", "order" = "default"}, requirements={"name" = "\w+"}, name="scrolltable_page", options={"expose" = true})
	 * @Cache(maxage="15")
	 */
	public function getPage($name, $number, $order = 'default', $filter = '')
	{
		$table = $this->getTable($name);
		$response = $table->getPage($number, $order, $filter);
		return new Response($response);
	}
	
	/**
	 * @Route("/{name}/info/{filter}", defaults={"filter" = ""}, requirements={"name" = "\w+"}, name="scrolltable_info", options={"expose" = true})
	 * @Cache(maxage="15")
	 */
	public function getInfo($name, $filter = "")
	{
		$table = $this->getTable($name);
		$request = $this->container->get('request');
		return new Response('<info><pc>'.($table->getPageCount($filter)).'</pc></info>');
	}
}