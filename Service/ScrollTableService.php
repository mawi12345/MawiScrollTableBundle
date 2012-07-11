<?php
namespace Mawi\Bundle\ScrollTableBundle\Service;

use Symfony\Component\HttpFoundation\Request;

use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\DependencyInjection\ContainerAware;
use Sensio\Bundle\FrameworkExtraBundle\Configuration\Route;

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
	 * @Route("/{name}/rows", requirements={"name" = "\w+"}, name="scrolltable_rows", options={"expose" = true})
	 */
	public function getRows($name)
	{
		$table = $this->getTable($name);
		$request = $this->container->get('request');
		$positions = $request->request->get('r');
		$orderBy = $request->request->get('o', array());
		$filter = $request->request->get('f', array());
		
		$positions[] = -1;
		$intervals = array();
		$start = $positions[0];
		$last = $start;
				
		foreach ($positions as $position) {
			if ($position > ($last + 1) || $position < 0) {
				$intervals[] = array('start' => $start, 'end' => $last);
				$start = $position;
			}
			$last = $position;
		}
		
		$response = '<r>';
		foreach ($intervals as $interval) {
			$response .= $table->getRows($interval['start'], $interval['end'], $orderBy, $filter);
		}
		$response .= '</r>';
		return new Response($response);
	}
	
	/**
	 * @Route("/{name}/info", requirements={"name" = "\w+"}, name="scrolltable_info", options={"expose" = true})
	 */
	public function getInfo($name)
	{
		$table = $this->getTable($name);
		$request = $this->container->get('request');
		$filter = $request->request->get('f', array());
		return new Response('<info><rc>'.$table->getRowCount($filter).'</rc></info>');
	}
}